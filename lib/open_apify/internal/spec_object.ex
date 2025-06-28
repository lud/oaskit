defmodule OpenApify.Internal.SpecObject do
  @moduledoc false

  # Setup for various protocols implemented by the Objects definition of the 3.1
  # specification.

  defmacro __using__(_) do
    quote do
      import OpenApify.Internal.Normalizer
      import unquote(__MODULE__)
      @behaviour OpenApify.Internal.Normalizer
      @behaviour Access
      snake_object_name =
        __MODULE__
        |> Module.split()
        |> List.last()
        |> Macro.underscore()

      object_name =
        snake_object_name
        |> String.replace(~r{(^|_).}, fn
          "_" <> char -> " " <> String.upcase(char)
          char -> " " <> String.upcase(char)
        end)

      object_fragment =
        snake_object_name
        |> String.replace("_", "-")
        |> Kernel.<>("-object")

      obect_link = "https://spec.openapis.org/oas/v3.1.1.html##{object_fragment}"

      @moduledoc "Representation of the [#{object_name} Object](#{obect_link}) in OpenAPI Specification."

      @impl Access
      def fetch(t, key) do
        Map.fetch(t, key)
      end

      @impl Access
      @spec get_and_update(term, term, term) :: no_return()
      def get_and_update(_t, _key, _fun) do
        raise "should not be used"
      end

      @impl Access
      @spec pop(term, term) :: no_return()
      def pop(_t, _key) do
        raise "should not be used"
      end

      defoverridable Access
      defoverridable OpenApify.Internal.Normalizer
    end
  end
end
