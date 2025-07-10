defmodule Oaskit.Internal.NormalizationContext do
  @moduledoc false
  @enforce_keys [
    # A list of keys to track the current nesting path of the normalized tree
    # (in reverse hierarchy).
    :rev_path,

    # A map of %{module => refname}. A refname is the last part of the path in
    # #/components/schemas/<refname>.
    #
    # When normalizing, if we see a module in a schema and the module is already
    # in here, we don't need to normalize the schema again.
    :seen_schema_mods,

    # A map of %{refname => normal schema} to define the #/components/schemas
    # part of the normalized spec.
    :components_schemas
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end
