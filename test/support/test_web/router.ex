defmodule Oaskit.TestWeb.Router do
  use Phoenix.Router

  pipeline :api_from_paths do
    plug Oaskit.Plugs.SpecProvider, spec: Oaskit.TestWeb.PathsApiSpec
  end

  pipeline :api_from_doc do
    plug Oaskit.Plugs.SpecProvider, spec: Oaskit.TestWeb.DeclarativeApiSpec
  end

  scope "/generated" do
    pipe_through :api_from_paths

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
      get "/generic", ParamController, :generic_param_types
      get "/arrays", ParamController, :array_types
      get "/boolean-schema-false", ParamController, :boolean_schema_false

      scope "/s/:shape" do
        get "/", ParamController, :scope_only
        get "/t/:theme", ParamController, :scope_and_single
        get "/t/:theme/c/:color", ParamController, :scope_and_two_path_params
      end
    end

    post "/no-html-errors", Oaskit.TestWeb.JsonErrorsController, :create_plant

    scope "/resp", Oaskit.TestWeb do
      get "/fortune-200-no-operation", ResponseController, :no_operation
      get "/fortune-200-valid", ResponseController, :valid
      get "/fortune-200-invalid", ResponseController, :invalid
      get "/fortune-200-no-content-def", ResponseController, :no_content_def
      get "/fortune-200-bad-content-type", ResponseController, :bad_content_type
      get "/fortune-500-default-resp", ResponseController, :default_resp
      get "/fortune-500-bad-default-resp", ResponseController, :invalid_default_resp
    end

    scope "/method", Oaskit.TestWeb do
      get "/p", MethodController, :single_fun
      post "/p", MethodController, :single_fun
      put "/p", MethodController, :single_fun
      patch "/p", MethodController, :single_fun
      delete "/p", MethodController, :single_fun
      options "/p", MethodController, :single_fun
      trace("/p", MethodController, :single_fun)
      head "/p", MethodController, :single_fun
    end
  end

  scope "/provided" do
    pipe_through :api_from_doc
    post "/potions", Oaskit.TestWeb.LabController, :create_potion
    get "/:lab/alchemists", Oaskit.TestWeb.LabController, :list_alchemists
    post "/:lab/alchemists", Oaskit.TestWeb.LabController, :search_alchemists
  end

  match :*, "/*path", Oaskit.TestWeb.Router.Catchall, :not_found, warn_on_verify: true
end

defmodule Oaskit.TestWeb.Router.Catchall do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: []

  @spec not_found(term, term) :: no_return()
  def not_found(conn, _) do
    send_resp(conn, 404, "Not Found (catchall)")
  end
end
