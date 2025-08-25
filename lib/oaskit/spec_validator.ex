defmodule Oaskit.SpecValidator do
  alias Oaskit.Plugs.ValidateRequest
  alias Oaskit.Spec.OpenAPI
  alias Oaskit.Validation.RequestValidator
  require Oaskit.Internal.Normalizer
  require Oaskit.Spec.Callback
  require Oaskit.Spec.Components
  require Oaskit.Spec.Contact
  require Oaskit.Spec.Discriminator
  require Oaskit.Spec.Encoding
  require Oaskit.Spec.Example
  require Oaskit.Spec.ExternalDocumentation
  require Oaskit.Spec.Header
  require Oaskit.Spec.Info
  require Oaskit.Spec.License
  require Oaskit.Spec.Link
  require Oaskit.Spec.MediaType
  require Oaskit.Spec.OAuthFlow
  require Oaskit.Spec.OAuthFlows
  require Oaskit.Spec.OpenAPI
  require Oaskit.Spec.Operation
  require Oaskit.Spec.Parameter
  require Oaskit.Spec.PathItem
  require Oaskit.Spec.Paths
  require Oaskit.Spec.Reference
  require Oaskit.Spec.RequestBody
  require Oaskit.Spec.Response
  require Oaskit.Spec.Responses
  require Oaskit.Spec.SchemaWrapper
  require Oaskit.Spec.SecurityRequirement
  require Oaskit.Spec.SecurityScheme
  require Oaskit.Spec.Server
  require Oaskit.Spec.ServerVariable
  require Oaskit.Spec.Tag
  require Oaskit.Spec.XML

  @moduledoc """
  A helper module used to cast and validate OpenAPI specifications into structs.

  This module is **NOT** responsible for validating requests, responses and
  payloads according to an OpenAPI specification (although it is involved in the
  process). That is the role of `#{inspect(ValidateRequest)}` and
  `#{inspect(RequestValidator)}`.

  This module validates the specification _itself_ according to the
  `#{inspect(Oaskit.Spec.OpenAPI)}` JSON Schema.
  """

  @openapi_schema JSV.build!(OpenAPI)

  @doc """
  Validates the given OpenAPI specification and returns an
  `#{inspect(Oaskit.Spec.OpenAPI)}` struct.

  Raises on error.
  """
  def validate!(data) do
    JSV.validate!(data, @openapi_schema)
  end

  @doc """
  Validates the given OpenAPI specification and returns an
  `#{inspect(Oaskit.Spec.OpenAPI)}` struct in a result tuple.
  """
  def validate(data) do
    JSV.validate(data, @openapi_schema)
  end
end
