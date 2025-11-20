defmodule Oaskit.TestWeb.Router do
  use Phoenix.Router

  @moduledoc false

  pipeline :api_from_paths do
    plug Oaskit.Plugs.SpecProvider, spec: Oaskit.TestWeb.PathsApiSpec
  end

  pipeline :api_from_doc do
    plug Oaskit.Plugs.SpecProvider, spec: Oaskit.TestWeb.DeclarativeApiSpec
  end

  pipeline :api_security do
    plug Oaskit.Plugs.SpecProvider, spec: Oaskit.TestWeb.SecurityApiSpec
  end

  pipeline :api_orval do
    plug Oaskit.Plugs.SpecProvider, spec: Oaskit.TestWeb.OrvalApiSpec
  end

  scope "/generated" do
    pipe_through :api_from_paths

    # Spec controller route for PathsApiSpec
    get "/openapi.json", Oaskit.SpecController,
      spec: true,
      resp_headers: %{"access-control-allow-origin" => "*"}

    get "/redoc", Oaskit.SpecController,
      redoc: "/generated/openapi.json",
      redoc_config: %{
        "minCharacterLengthToInitSearch" => 1,
        "hideDownloadButtons" => true
      }

    scope "/meta", Oaskit.TestWeb do
      get "/before-metas", MetaController, :before_metas
      get "/after-metas", MetaController, :after_metas
      get "/overrides-param", MetaController, :overrides_param
    end

    scope "/body", Oaskit.TestWeb do
      post "/inline-single", BodyController, :inline_single
      post "/module-single", BodyController, :module_single
      post "/module-single-no-required", BodyController, :module_single_not_required
      post "/form", BodyController, :handle_form
      post "/undefined-operation", BodyController, :undefined_operation
      post "/ignored-action", BodyController, :ignored_action
      post "/wildcard", BodyController, :wildcard_media_type
      post "/boolean-schema-false", BodyController, :boolean_schema_false

      # Manual tests
      post "/manual-form-handle", BodyController, :manual_form_handle
      get "/manual-form-show", BodyController, :manual_form_show
    end

    get "/no-params", Oaskit.TestWeb.ParamController, :no_params

    scope "/params/:slug", Oaskit.TestWeb do
      get "/t/:theme", ParamController, :single_path_param
      get "/t/:theme/c/:color", ParamController, :two_path_params

      scope "/s/:shape" do
        get "/", ParamController, :scope_only
        get "/t/:theme", ParamController, :scope_and_single
        get "/t/:theme/c/:color", ParamController, :scope_and_two_path_params
      end

      get "/generic", ParamController, :generic_param_types
      get "/arrays", ParamController, :array_types
      get "/array-ref", ParamController, :array_ref
      get "/bracket-types", ParamController, :bracket_types
      get "/boolean-schema-false", ParamController, :boolean_schema_false
      get "/header-param", ParamController, :header_param
    end

    post "/no-html-errors", Oaskit.TestWeb.JsonErrorsController, :create_plant

    scope "/resp", Oaskit.TestWeb do
      get "/fortune-200-no-operation", ResponseController, :no_operation
      post "/fortune-200-req-body", ResponseController, :require_body
      get "/fortune-200-valid", ResponseController, :valid
      get "/fortune-200-valid-from-ref", ResponseController, :valid_from_ref
      get "/fortune-200-valid-no-operation", ResponseController, :valid_no_operation
      get "/fortune-200-invalid", ResponseController, :invalid
      get "/fortune-200-no-content-def", ResponseController, :no_content_def
      get "/fortune-200-bad-content-type", ResponseController, :bad_content_type
      get "/fortune-500-default-resp", ResponseController, :default_resp
      get "/fortune-500-bad-default-resp", ResponseController, :invalid_default_resp
    end

    scope "/extensions", Oaskit.TestWeb do
      get "/with-json-encodable-ext", ExtensionController, :with_json_encodable_ext
      get "/with-public-and-private", ExtensionController, :with_public_and_private
      get "/with-struct", ExtensionController, :with_struct
    end

    scope "/method", Oaskit.TestWeb do
      get "/p", MethodController, :same_fun
      post "/p", MethodController, :same_fun
      put "/p", MethodController, :same_fun
      patch "/p", MethodController, :same_fun
      delete "/p", MethodController, :same_fun
      options "/p", MethodController, :same_fun
      trace("/p", MethodController, :same_fun)
      head "/p", MethodController, :same_fun
    end
  end

  scope "/security", Oaskit.TestWeb do
    pipe_through :api_security

    post "/no-security", SecurityController, :no_security
    post "/empty-security", SecurityController, :empty_security
    post "/no-scopes", SecurityController, :no_scopes
    post "/with-scopes", SecurityController, :with_scopes
    post "/multi-scheme-security", SecurityController, :multi_scheme_security
    post "/multi-choice-security", SecurityController, :multi_choice_security
  end

  scope "/provided", Oaskit.TestWeb do
    pipe_through :api_from_doc

    # Spec controller route for DeclarativeApiSpec

    post "/potions", LabController, :create_potion
    get "/:lab/alchemists", LabController, :list_alchemists
    post "/:lab/alchemists", LabController, :search_alchemists
    get "/potions/extensions", LabController, :extensions_check
  end

  scope "/orval" do
    pipe_through :api_orval

    get "/test-arrays", Oaskit.TestWeb.OrvalController, :test_arrays
    post "/users", Oaskit.TestWeb.OrvalController, :create_user
  end

  # outside of the scope but we pass the spec
  get "/provided-openapi.json", Oaskit.SpecController, spec: Oaskit.TestWeb.DeclarativeApiSpec

  match :*, "/*path", Oaskit.TestWeb.Router.Catchall, :not_found, warn_on_verify: true
end

defmodule Oaskit.TestWeb.Router.Catchall do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: []

  @moduledoc false
  @spec not_found(term, term) :: no_return()
  def not_found(conn, _) do
    send_resp(conn, 404, "Not Found (catchall)")
  end
end
