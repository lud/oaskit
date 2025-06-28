defmodule OpenApify.Internal.SpecValidator do
  alias OpenApify.Spec.OpenAPI
  require OpenApify.Internal.Normalizer
  require OpenApify.Spec.Callback
  require OpenApify.Spec.Components
  require OpenApify.Spec.Contact
  require OpenApify.Spec.Discriminator
  require OpenApify.Spec.Encoding
  require OpenApify.Spec.Example
  require OpenApify.Spec.ExternalDocumentation
  require OpenApify.Spec.Header
  require OpenApify.Spec.Info
  require OpenApify.Spec.License
  require OpenApify.Spec.Link
  require OpenApify.Spec.MediaType
  require OpenApify.Spec.OAuthFlow
  require OpenApify.Spec.OAuthFlows
  require OpenApify.Spec.OpenAPI
  require OpenApify.Spec.Operation
  require OpenApify.Spec.Parameter
  require OpenApify.Spec.PathItem
  require OpenApify.Spec.Paths
  require OpenApify.Spec.Reference
  require OpenApify.Spec.RequestBody
  require OpenApify.Spec.Response
  require OpenApify.Spec.Responses
  require OpenApify.Spec.SchemaWrapper
  require OpenApify.Spec.SecurityRequirement
  require OpenApify.Spec.SecurityScheme
  require OpenApify.Spec.Server
  require OpenApify.Spec.ServerVariable
  require OpenApify.Spec.Tag
  require OpenApify.Spec.XML

  @moduledoc false

  @openapi_schema JSV.build!(OpenAPI)

  def validate!(data) do
    JSV.validate!(data, @openapi_schema)
  end

  def validate(data) do
    JSV.validate(data, @openapi_schema)
  end
end
