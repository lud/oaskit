defmodule Oaskit.Internal.Normalizer.ExtensionPoint do
  @moduledoc false

  defstruct [:original_key, :original_value]

  defimpl JSV.Normalizer.Normalize do
    def normalize(%{original_value: v}) do
      # The orginal value may be a struct, but the normalizer will not accept
      # that return value so we call a new normalizer instance on the value.
      JSV.Normalizer.normalize(v)
    end
  end

  if Code.ensure_loaded?(JSON.Encoder) do
    defimpl JSON.Encoder do
      def encode(%{original_value: v}, encoder) do
        encoder.(v)
      end
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(%{original_value: v}, opts) do
        Jason.Encoder.impl_for!(v).encode(v, opts)
      end
    end
  end
end
