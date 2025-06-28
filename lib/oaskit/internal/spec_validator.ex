defmodule Oaskit.Internal.SpecValidator do
  alias Oaskit.Spec.OpenAPI
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

  @moduledoc false

  @openapi_schema JSV.build!(OpenAPI)

  def validate!(data) do
    JSV.validate!(data, @openapi_schema)
  end

  def validate(data) do
    JSV.validate(data, @openapi_schema)
  end
end
