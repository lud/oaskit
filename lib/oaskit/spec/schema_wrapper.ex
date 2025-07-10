defmodule Oaskit.Spec.SchemaWrapper do
  @moduledoc """
  A wrapper to embed JSON schemas of any supported type (modules, maps,
  booleans) in an OpenAPI specification.
  """

  @deprecated "use #{inspect(__MODULE__)}.json_schema/0 instead"
  @doc false
  def schema do
    json_schema()
  end

  def json_schema do
    %{
      title: "SchemaWrapper",
      description: "Allows definition of input and output data types."
    }
  end
end
