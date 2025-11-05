defmodule Oaskit.Internal.ControllerBuilder do
  # Module used to build Operation structs and sub structs from the operation
  # macro.
  @moduledoc false

  @undef :__undef__

  defstruct [:target, :input, :output]

  def make(spec, target) when is_list(spec) when is_map(spec) do
    %__MODULE__{target: target, input: spec, output: %{}}
  end

  def make(other, target) do
    raise ArgumentError,
          "invalid value for Open API model #{inspect(target)} in controller, " <>
            "expected keyword list or map, got: #{inspect(other)}"
  end

  def nocast(value) do
    {:ok, value}
  end

  defp with_cast(builder, key, value, caster) do
    %__MODULE__{output: output} = builder

    case cast(value, caster) do
      {:ok, cast_value} ->
        %{builder | output: Map.put(output, key, cast_value)}

      {:error, errmsg} when is_binary(errmsg) ->
        raise ArgumentError,
          message:
            "could not cast key #{inspect(key)} when building" <>
              " #{inspect(builder.target)}, got: #{errmsg}"
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

  def put(builder, key, value) when is_atom(key) do
    %__MODULE__{output: output} = builder
    %{builder | output: set(output, key, value)}
  end

  def rename_input(builder, inkey, outkey) do
    %__MODULE__{input: input} = builder

    case pop(input, inkey) do
      {:ok, value, input} -> %{builder | input: set(input, outkey, value)}
      :error -> builder
    end
  end

  def take_required(builder, key, cast \\ &nocast/1) do
    %__MODULE__{target: target, input: input} = builder

    case pop(input, key) do
      {:ok, value, input} ->
        with_cast(%{builder | input: input}, key, value, cast)

      :error ->
        raise ArgumentError, "key #{inspect(key)} is required when building #{inspect(target)}"
    end
  end

  def take_default(builder, key, default, cast \\ &nocast/1) do
    %__MODULE__{input: input, output: output} = builder

    case pop(input, key) do
      {:ok, value, input} -> with_cast(%{builder | input: input}, key, value, cast)
      :error -> %{builder | output: Map.put(output, key, default)}
    end
  end

  def take_default_lazy(builder, key, generate, cast \\ &nocast/1)
      when is_function(generate, 0) do
    %__MODULE__{input: input, output: output} = builder

    case pop(input, key) do
      {:ok, value, input} -> with_cast(%{builder | input: input}, key, value, cast)
      :error -> %{builder | output: Map.put(output, key, generate.())}
    end
  end

  def ensure_schema(schema) when is_map(schema) when is_boolean(schema) do
    {:ok, schema}
  end

  def ensure_schema(schema) when is_atom(schema) do
    case JSV.Schema.schema_module?(schema) do
      true -> {:ok, schema}
      false -> {:error, {:invalid_schema, schema}}
    end
  end

  def into(builder) do
    %__MODULE__{target: target, output: output} = builder
    struct!(target, output)
  end
end
