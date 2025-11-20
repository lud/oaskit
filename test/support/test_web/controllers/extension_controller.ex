defmodule Oaskit.TestWeb.ExtensionController.SomeStruct do
  # Custom struct to be used as an extension.
  # Infortunately it needs to be normalizeable

  @moduledoc false
  defstruct [:foo]

  defimpl JSV.Normalizer.Normalize do
    def normalize(t) do
      Map.from_struct(t)
    end
  end
end

defmodule Oaskit.TestWeb.ExtensionController do
  alias Oaskit.TestWeb.Responder
  use Oaskit.TestWeb, :controller

  @moduledoc false

  operation :with_json_encodable_ext,
    some_extension: "hello",
    responses: dummy_responses()

  def with_json_encodable_ext(conn, params) do
    Responder.reply(conn, params)
  end

  operation :with_public_and_private,
    "x-public-ext": "some public",
    "private-ext": "some private",
    responses: dummy_responses()

  def with_public_and_private(conn, params) do
    Responder.reply(conn, params)
  end

  operation :with_non_json,
    "private-struct": %Oaskit.TestWeb.ExtensionController.SomeStruct{foo: :bar},
    responses: dummy_responses()

  def with_non_json(conn, params) do
    Responder.reply(conn, params)
  end
end
