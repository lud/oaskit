defmodule OpenApify.Internal.ControllerBuilder do
  # Module used to build Operation structs and sub structs from the operation
  # macro.
  @moduledoc false

  @undef :__undef__

  def make(opts, target) when is_list(opts) when is_map(opts) do
    {target, opts, %{}}
  end

  def make(other, target) do
    raise ArgumentError,
          "invalid value for Open API model #{inspect(target)} in controller, " <>
            "expected keyword list or map, got: #{inspect(other)}"
  end

  def nocast(value) do
    {:ok, value}
  end

  defp with_cast(target, input, output, key, value, caster) do
    case cast(value, caster) do
      {:ok, cast_value} ->
        {target, input, Map.put(output, key, cast_value)}

      {:error, errmsg} when is_binary(errmsg) ->
        raise ArgumentError,
          message:
            "could not cast key #{inspect(key)} when building #{inspect(target)}, got: #{errmsg}"
    end
  end

  defp cast(value, {caster, errmsg}) when is_function(caster, 1) do
    cast(value, caster, errmsg)
  end

  defp cast(value, caster) when is_function(caster, 1) do
    cast(value, caster, "invalid value")
  end

  # cast value expect result tuples because we may want to use generic casts
  # from other libraries. But the whole spec building otherwise just raises
  # exceptions.
  defp cast(value, caster, errmsg) do
    case caster.(value) do
      {:ok, _} = fine -> fine
      {:error, reason} -> {:error, "#{errmsg}, #{inspect(reason)}, value: #{inspect(value)}"}
    end
  end

  defp pop(container, key) when is_map(container) do
    case Map.pop(container, key, @undef) do
      {@undef, _} -> :error
      {value, container} -> {:ok, value, container}
    end
  end

  defp pop(container, key) when is_list(container) do
    case Keyword.pop(container, key, @undef) do
      {@undef, _} -> :error
      {value, container} -> {:ok, value, container}
    end
  end

  defp pop(container, key) do
    raise "cannot fetch key #{inspect(key)} from data, expected a map or keyword list, got: #{inspect(container)}"
  end

  defp set(container, key, value) when is_list(container) do
    Keyword.put(container, key, value)
  end

  defp set(container, key, value) when is_map(container) do
    Map.put(container, key, value)
  end

  def put({target, input, output}, key, value) when is_atom(key) do
    {target, input, set(output, key, value)}
  end

  def rename_input({target, input, output}, inkey, outkey) do
    case pop(input, inkey) do
      {:ok, value, input} -> {target, set(input, outkey, value), output}
      :error -> {target, input, output}
    end
  end

  def take_required({target, input, output}, key, cast \\ &nocast/1) do
    case pop(input, key) do
      {:ok, value, input} ->
        with_cast(target, input, output, key, value, cast)

      :error ->
        raise ArgumentError, "key #{inspect(key)} is required when building #{inspect(target)}"
    end
  end

  def take_default({target, input, output}, key, default, cast \\ &nocast/1) do
    case pop(input, key) do
      {:ok, value, input} -> with_cast(target, input, output, key, value, cast)
      :error -> {target, input, Map.put(output, key, default)}
    end
  end

  def take_default_lazy({target, input, output}, key, generate, cast \\ &nocast/1)
      when is_function(generate, 0) do
    case pop(input, key) do
      {:ok, value, input} -> with_cast(target, input, output, key, value, cast)
      :error -> {target, input, Map.put(output, key, generate.())}
    end
  end

  def into({target, _, output}) do
    struct!(target, output)
  end
end
