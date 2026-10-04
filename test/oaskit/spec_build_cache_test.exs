defmodule Oaskit.SpecBuildCacheTest do
  alias Oaskit.TestWeb.PathsApiSpec
  use ExUnit.Case, async: true

  defmodule CacheSpec do
    use Oaskit

    @impl true
    def spec do
      PathsApiSpec.spec()
    end
  end

  defmodule WarmupSpec do
    use Oaskit

    @impl true
    def spec do
      PathsApiSpec.spec()
    end
  end

  defmodule ChildWarmupSpec do
    use Oaskit

    @impl true
    def spec do
      PathsApiSpec.spec()
    end
  end

  defmodule BrokenSpec do
    use Oaskit

    @impl true
    def spec do
      raise "broken spec"
    end
  end

  defp unique_cache_key do
    key = {:oaskit_cache_test, make_ref()}
    on_exit(fn -> :persistent_term.erase(key) end)
    key
  end

  describe "cached/3" do
    test "concurrent cache misses call the generator only once" do
      key = unique_cache_key()
      counter = :counters.new(1, [])

      generator = fn ->
        :counters.add(counter, 1, 1)
        Process.sleep(200)
        :built_value
      end

      results =
        1..20
        |> Enum.map(fn _ -> Task.async(fn -> Oaskit.cached(CacheSpec, key, generator) end) end)
        |> Task.await_many(10_000)

      assert Enum.all?(results, &(&1 == :built_value))
      assert 1 == :counters.get(counter, 1)
      assert {:ok, :built_value} = CacheSpec.cache({:get, key})
      assert [] == Registry.lookup(Oaskit.SpecBuilderLockRegistry, key)
    end

    test "the lock is released when the generator raises" do
      key = unique_cache_key()

      assert_raise RuntimeError, "build failure", fn ->
        Oaskit.cached(CacheSpec, key, fn -> raise "build failure" end)
      end

      assert [] == Registry.lookup(Oaskit.SpecBuilderLockRegistry, key)
      assert :error = CacheSpec.cache({:get, key})

      assert :built_value == Oaskit.cached(CacheSpec, key, fn -> :built_value end)
    end

    test "the generator is not called on cache hit" do
      key = unique_cache_key()
      :ok = CacheSpec.cache({:put, key, :cached_value})

      assert :cached_value ==
               Oaskit.cached(CacheSpec, key, fn -> flunk("generator should not be called") end)
    end
  end

  describe "warmup_spec_cache/2" do
    setup do
      request_key = {:oaskit_cache, WarmupSpec, false, nil}
      responses_key = {:oaskit_cache, WarmupSpec, true, nil}

      on_exit(fn ->
        :persistent_term.erase(request_key)
        :persistent_term.erase(responses_key)
      end)

      %{request_key: request_key, responses_key: responses_key}
    end

    test "builds the request variant only by default", ctx do
      assert :ok = Oaskit.warmup_spec_cache(WarmupSpec)
      assert {:ok, {_, _}} = WarmupSpec.cache({:get, ctx.request_key})
      assert :error = WarmupSpec.cache({:get, ctx.responses_key})

      # The cached value is returned by build_spec!
      assert {:ok, built} = WarmupSpec.cache({:get, ctx.request_key})
      assert built === Oaskit.build_spec!(WarmupSpec)
    end

    test "builds the responses variant with the :responses option", ctx do
      assert :ok = Oaskit.warmup_spec_cache(WarmupSpec, responses: true)
      assert {:ok, {_, _}} = WarmupSpec.cache({:get, ctx.request_key})
      assert {:ok, {_, _}} = WarmupSpec.cache({:get, ctx.responses_key})
    end
  end

  describe "SpecCacheWarmup" do
    setup do
      request_key = {:oaskit_cache, ChildWarmupSpec, false, nil}
      responses_key = {:oaskit_cache, ChildWarmupSpec, true, nil}

      on_exit(fn ->
        :persistent_term.erase(request_key)
        :persistent_term.erase(responses_key)
      end)

      %{request_key: request_key, responses_key: responses_key}
    end

    test "builds the spec when started and returns :ignore", ctx do
      assert {:ok, :undefined} = start_supervised({Oaskit.SpecCacheWarmup, spec: ChildWarmupSpec})
      assert {:ok, {_, _}} = ChildWarmupSpec.cache({:get, ctx.request_key})
      assert :error = ChildWarmupSpec.cache({:get, ctx.responses_key})
    end

    test "forwards the :responses option", ctx do
      assert {:ok, :undefined} =
               start_supervised({Oaskit.SpecCacheWarmup, spec: ChildWarmupSpec, responses: true})

      assert {:ok, {_, _}} = ChildWarmupSpec.cache({:get, ctx.request_key})
      assert {:ok, {_, _}} = ChildWarmupSpec.cache({:get, ctx.responses_key})
    end

    test "fails to start when the spec cannot be built" do
      assert {:error, {{:EXIT, {%RuntimeError{message: "broken spec"}, _}}, _}} =
               start_supervised({Oaskit.SpecCacheWarmup, spec: BrokenSpec})
    end
  end
end
