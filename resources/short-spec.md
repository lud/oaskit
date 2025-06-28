# OpenAPI Schema Objects

## OpenAPI Object
Root object of the OpenAPI Description.

- **openapi** (`string`) - Version number of the OpenAPI Specification. **REQUIRED**
- **info** (`Info Object`) - Metadata about the API. **REQUIRED**
- **jsonSchemaDialect** (`string`) - Default value for the `$schema` keyword within Schema Objects.
- **servers** (`[Server Object]`) - Array of Server Objects providing connectivity information.
- **paths** (`Paths Object`) - Available paths and operations for the API.
- **webhooks** (`Map[string, Path Item Object]`) - Incoming webhooks that may be received as part of this API.
- **components** (`Components Object`) - Element to hold various Objects for the OpenAPI Description.
- **security** (`[Security Requirement Object]`) - Security mechanisms that can be used across the API.
- **tags** (`[Tag Object]`) - List of tags used by the OpenAPI Description with additional metadata.
- **externalDocs** (`External Documentation Object`) - Additional external documentation.

## Info Object
Provides metadata about the API.

- **title** (`string`) - Title of the API. **REQUIRED**
- **summary** (`string`) - Short summary of the API.
- **description** (`string`) - Description of the API.
- **termsOfService** (`string`) - URI for the Terms of Service for the API.
- **contact** (`Contact Object`) - Contact information for the exposed API.
- **license** (`License Object`) - License information for the exposed API.
- **version** (`string`) - Version of the OpenAPI Document. **REQUIRED**

## Contact Object
Contact information for the exposed API.

- **name** (`string`) - Identifying name of the contact person/organization.
- **url** (`string`) - URI for the contact information.
- **email** (`string`) - Email address of the contact person/organization.

## License Object
License information for the exposed API.

- **name** (`string`) - License name used for the API. **REQUIRED**
- **identifier** (`string`) - SPDX expression for the API. Mutually exclusive with `url`.
- **url** (`string`) - URI for the license used for the API. Mutually exclusive with `identifier`.

## Server Object
An object representing a Server.

- **url** (`string`) - URL to the target host. Supports Server Variables. **REQUIRED**
- **description** (`string`) - Optional string describing the host designated by the URL.
- **variables** (`Map[string, Server Variable Object]`) - Map between variable name and its value for substitution in server's URL template.

## Server Variable Object
Object representing a Server Variable for server URL template substitution.

- **enum** (`[string]`) - Enumeration of string values for substitution options from a limited set.
- **default** (`string`) - Default value to use for substitution. **REQUIRED**
- **description** (`string`) - Optional description for the server variable.

## Components Object
Holds reusable objects for different aspects of the OAS.

- **schemas** (`Map[string, Schema Object]`) - Reusable Schema Objects.
- **responses** (`Map[string, Response Object | Reference Object]`) - Reusable Response Objects.
- **parameters** (`Map[string, Parameter Object | Reference Object]`) - Reusable Parameter Objects.
- **examples** (`Map[string, Example Object | Reference Object]`) - Reusable Example Objects.
- **requestBodies** (`Map[string, Request Body Object | Reference Object]`) - Reusable Request Body Objects.
- **headers** (`Map[string, Header Object | Reference Object]`) - Reusable Header Objects.
- **securitySchemes** (`Map[string, Security Scheme Object | Reference Object]`) - Reusable Security Scheme Objects.
- **links** (`Map[string, Link Object | Reference Object]`) - Reusable Link Objects.
- **callbacks** (`Map[string, Callback Object | Reference Object]`) - Reusable Callback Objects.
- **pathItems** (`Map[string, Path Item Object]`) - Reusable Path Item Objects.

## Paths Object
Holds the relative paths to individual endpoints and their operations.

- **/{path}** (`Path Item Object`) - Relative path to an individual endpoint. Field name must begin with a forward slash.

## Path Item Object
Describes operations available on a single path.

- **$ref** (`string`) - Allows for a referenced definition of this path item.
- **summary** (`string`) - Optional string summary for all operations in this path.
- **description** (`string`) - Optional string description for all operations in this path.
- **get** (`Operation Object`) - Definition of a GET operation on this path.
- **put** (`Operation Object`) - Definition of a PUT operation on this path.
- **post** (`Operation Object`) - Definition of a POST operation on this path.
- **delete** (`Operation Object`) - Definition of a DELETE operation on this path.
- **options** (`Operation Object`) - Definition of an OPTIONS operation on this path.
- **head** (`Operation Object`) - Definition of a HEAD operation on this path.
- **patch** (`Operation Object`) - Definition of a PATCH operation on this path.
- **trace** (`Operation Object`) - Definition of a TRACE operation on this path.
- **servers** (`[Server Object]`) - Alternative servers array for all operations in this path.
- **parameters** (`[Parameter Object | Reference Object]`) - Parameters applicable for all operations under this path.

## Operation Object
Describes a single API operation on a path.

- **tags** (`[string]`) - Tags for API documentation control.
- **summary** (`string`) - Short summary of what the operation does.
- **description** (`string`) - Verbose explanation of the operation behavior.
- **externalDocs** (`External Documentation Object`) - Additional external documentation.
- **operationId** (`string`) - Unique string used to identify the operation.
- **parameters** (`[Parameter Object | Reference Object]`) - List of parameters applicable for this operation.
- **requestBody** (`Request Body Object | Reference Object`) - Request body applicable for this operation.
- **responses** (`Responses Object`) - List of possible responses from executing this operation.
- **callbacks** (`Map[string, Callback Object | Reference Object]`) - Map of possible out-of-band callbacks.
- **deprecated** (`boolean`) - Declares this operation to be deprecated.
- **security** (`[Security Requirement Object]`) - Security mechanisms that can be used for this operation.
- **servers** (`[Server Object]`) - Alternative servers array for this operation.

## External Documentation Object
Allows referencing an external resource for extended documentation.

- **description** (`string`) - Description of the target documentation.
- **url** (`string`) - URI for the target documentation. **REQUIRED**

## Parameter Object
Describes a single operation parameter.

Common Fixed Fields:
- **name** (`string`) - Name of the parameter. **REQUIRED**
- **in** (`string`) - Location of the parameter. Values: "query", "header", "path", "cookie". **REQUIRED**
- **description** (`string`) - Brief description of the parameter.
- **required** (`boolean`) - Determines whether this parameter is mandatory. Required and must be true for path parameters.
- **deprecated** (`boolean`) - Specifies that a parameter is deprecated.
- **allowEmptyValue** (`boolean`) - If true, zero-length strings may be passed for optional parameters.

Fixed Fields for use with `schema`:
- **style** (`string`) - Describes how the parameter value will be serialized.
- **explode** (`boolean`) - When true, parameter values of type array or object generate separate parameters.
- **allowReserved** (`boolean`) - When true, reserved characters in parameter values are allowed.
- **schema** (`Schema Object`) - Schema defining the parameter type.
- **example** (`Any`) - Example of the parameter's potential value.
- **examples** (`Map[string, Example Object | Reference Object]`) - Examples of the parameter's potential value.

Fixed Fields for use with `content`:
- **content** (`Map[string, Media Type Object]`) - Map containing parameter representations.

## Request Body Object
Describes a single request body.

- **description** (`string`) - Brief description of the request body.
- **content** (`Map[string, Media Type Object]`) - Content of the request body. **REQUIRED**
- **required** (`boolean`) - Determines if the request body is required in the request.

## Media Type Object
Provides schema and examples for a media type.

- **schema** (`Schema Object`) - Schema defining the content.
- **example** (`Any`) - Example of the media type.
- **examples** (`Map[string, Example Object | Reference Object]`) - Examples of the media type.
- **encoding** (`Map[string, Encoding Object]`) - Map between property name and encoding information.

## Encoding Object
A single encoding definition applied to a single schema property.

Common Fixed Fields:
- **contentType** (`string`) - Content-Type for encoding a specific property.
- **headers** (`Map[string, Header Object | Reference Object]`) - Map allowing additional information as headers.

Fixed Fields for RFC6570-style Serialization:
- **style** (`string`) - Describes how a property value will be serialized.
- **explode** (`boolean`) - When true, array/object properties generate separate parameters.
- **allowReserved** (`boolean`) - When true, reserved characters in values are allowed.

## Responses Object
Container for expected responses of an operation.

- **default** (`Response Object | Reference Object`) - Documentation of responses other than ones declared for specific HTTP response codes.
- **{HTTP Status Code}** (`Response Object | Reference Object`) - Expected response for that HTTP status code.

## Response Object
Describes a single response from an API operation.

- **description** (`string`) - Description of the response. **REQUIRED**
- **headers** (`Map[string, Header Object | Reference Object]`) - Maps header names to their definitions.
- **content** (`Map[string, Media Type Object]`) - Map of potential response payloads.
- **links** (`Map[string, Link Object | Reference Object]`) - Map of operations links that can be followed from the response.

## Callback Object
Map of possible out-of-band callbacks related to the parent operation.

- **{expression}** (`Path Item Object`) - Path Item Object used to define a callback request and expected responses.

## Example Object
Groups an example value with metadata.

- **summary** (`string`) - Short description for the example.
- **description** (`string`) - Long description for the example.
- **value** (`Any`) - Embedded literal example. Mutually exclusive with `externalValue`.
- **externalValue** (`string`) - URI that identifies the literal example. Mutually exclusive with `value`.

## Link Object
Represents a possible design-time link for a response.

- **operationRef** (`string`) - URI reference to an OAS operation. Mutually exclusive with `operationId`.
- **operationId** (`string`) - Name of an existing, resolvable OAS operation. Mutually exclusive with `operationRef`.
- **parameters** (`Map[string, Any | {expression}]`) - Map of parameters to pass to the linked operation.
- **requestBody** (`Any | {expression}`) - Value or expression to use as request body when calling the target operation.
- **description** (`string`) - Description of the link.
- **server** (`Server Object`) - Server object to be used by the target operation.

## Header Object
Describes a single header.

Common Fixed Fields:
- **description** (`string`) - Brief description of the header.
- **required** (`boolean`) - Determines whether this header is mandatory.
- **deprecated** (`boolean`) - Specifies that the header is deprecated.

Fixed Fields for use with `schema`:
- **style** (`string`) - Describes how the header value will be serialized. Default and only legal value is "simple".
- **explode** (`boolean`) - When true, array/object values generate a comma-separated list.
- **schema** (`Schema Object | Reference Object`) - Schema defining the header type.
- **example** (`Any`) - Example of the header's potential value.
- **examples** (`Map[string, Example Object | Reference Object]`) - Examples of the header's potential value.

Fixed Fields for use with `content`:
- **content** (`Map[string, Media Type Object]`) - Map containing header representations.

## Tag Object
Adds metadata to a single tag.

- **name** (`string`) - Name of the tag. **REQUIRED**
- **description** (`string`) - Description for the tag.
- **externalDocs** (`External Documentation Object`) - Additional external documentation for this tag.

## Reference Object
Allows referencing other components in the OpenAPI Description.

- **$ref** (`string`) - Reference identifier in the form of a URI. **REQUIRED**
- **summary** (`string`) - Summary that should override the referenced component's summary.
- **description** (`string`) - Description that should override the referenced component's description.

## Schema Object
Allows definition of input and output data types.

- **discriminator** (`Discriminator Object`) - Adds support for polymorphism.
- **xml** (`XML Object`) - Metadata to describe the XML representation of this property.
- **externalDocs** (`External Documentation Object`) - Additional external documentation for this schema.
- **example** (`Any`) - Example of an instance for this schema. (Deprecated in favor of `examples`)

## Discriminator Object
Provides a hint about the expected schema when request bodies/responses may be one of several schemas.

- **propertyName** (`string`) - Name of the property in the payload with the discriminating value. **REQUIRED**
- **mapping** (`Map[string, string]`) - Mappings between payload values and schema names or URI references.

## XML Object
Metadata for fine-tuned XML model definitions.

- **name** (`string`) - Replaces the name of the element/attribute used for the schema property.
- **namespace** (`string`) - URI of the namespace definition.
- **prefix** (`string`) - Prefix to be used for the name.
- **attribute** (`boolean`) - Whether the property translates to an attribute instead of an element.
- **wrapped** (`boolean`) - Whether the array is wrapped (for array definitions only).

## Security Scheme Object
Defines a security scheme for operations.

- **type** (`string`) - Type of the security scheme. Values: "apiKey", "http", "mutualTLS", "oauth2", "openIdConnect". **REQUIRED**
- **description** (`string`) - Description for security scheme.
- **name** (`string`) - Name of the header, query or cookie parameter (for apiKey). **REQUIRED** for apiKey.
- **in** (`string`) - Location of the API key. Values: "query", "header", "cookie". **REQUIRED** for apiKey.
- **scheme** (`string`) - HTTP Authentication scheme name. **REQUIRED** for http.
- **bearerFormat** (`string`) - Format of the bearer token (for http with "bearer" scheme).
- **flows** (`OAuth Flows Object`) - Configuration for the supported flow types. **REQUIRED** for oauth2.
- **openIdConnectUrl** (`string`) - URL to discover OpenID Connect configuration. **REQUIRED** for openIdConnect.

## OAuth Flows Object
Configures supported OAuth Flows.

- **implicit** (`OAuth Flow Object`) - Configuration for OAuth Implicit flow.
- **password** (`OAuth Flow Object`) - Configuration for OAuth Resource Owner Password flow.
- **clientCredentials** (`OAuth Flow Object`) - Configuration for OAuth Client Credentials flow.
- **authorizationCode** (`OAuth Flow Object`) - Configuration for OAuth Authorization Code flow.

## OAuth Flow Object
Configuration details for a supported OAuth Flow.

- **authorizationUrl** (`string`) - Authorization URL for this flow. **REQUIRED** for implicit, authorizationCode.
- **tokenUrl** (`string`) - Token URL for this flow. **REQUIRED** for password, clientCredentials, authorizationCode.
- **refreshUrl** (`string`) - URL for obtaining refresh tokens.
- **scopes** (`Map[string, string]`) - Available scopes for the OAuth2 security scheme. **REQUIRED**

## Security Requirement Object
Lists required security schemes to execute an operation.

- **{name}** (`[string]`) - Each name must correspond to a security scheme. Value is a list of scope names for oauth2/openIdConnect or role names for other types.