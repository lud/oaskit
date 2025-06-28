defmodule OpenApify.Spec.SchemaWrapper do
  require JSV

  # Allows definition of input and output data types.
  def schema do
    %{
      title: "SchemaWrapper",
      description: "Allows definition of input and output data types."
    }
  end
end
