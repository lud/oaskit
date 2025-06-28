defmodule Oaskit.Errors do
  alias Oaskit.Internal.Normalizer
  @moduledoc false

  defmodule InvalidBodyError do
    @enforce_keys [:value, :validation_error]
    defexception value: nil, validation_error: nil
    @opaque t :: %__MODULE__{}

    def message(%{validation_error: verr}) do
      """
      invalid body

      #{Exception.message(verr)}
      """
    end
  end

  defmodule InvalidParameterError do
    @enforce_keys [:name, :in, :value, :validation_error]
    defexception name: nil, in: nil, value: nil, validation_error: nil
    @opaque t :: %__MODULE__{}

    def message(%{in: loc, name: name, validation_error: verr}) do
      """
      invalid parameter #{name} in #{loc}

      #{Exception.message(verr)}
      """
    end
  end

  defmodule UnsupportedMediaTypeError do
    @enforce_keys [:media_type]
    defexception media_type: nil, value: nil
    @opaque t :: %__MODULE__{}

    def message(%{media_type: media_type}) do
      "cannot validate media type #{media_type}"
    end
  end

  defmodule MissingParameterError do
    @enforce_keys [:name, :in]
    defexception name: nil, in: nil
    @opaque t :: %__MODULE__{}

    def message(%{in: loc, name: name}) do
      "missing parameter #{name} in #{loc}"
    end
  end

  defmodule NormalizeError do
    defexception ctx: nil, reason: nil
    @opaque t :: %__MODULE__{}

    def message(%{ctx: ctx, reason: reason}) when is_binary(reason) do
      "normalization error in #{format_error_path(ctx)}: #{reason}"
    end

    defp format_error_path(ctx) do
      # For errors no need to encode as a json pointer, we just wrap the key in
      # square brackets if it contains slashes
      wrapped =
        Enum.map_intersperse(Normalizer.current_path(ctx), "/", fn
          segment when is_binary(segment) ->
            if String.contains?(segment, "/") do
              [?[, segment, ?]]
            else
              segment
            end

          segment when is_integer(segment) ->
            Integer.to_string(segment)
        end)

      ["#/", wrapped]
    end
  end
end
