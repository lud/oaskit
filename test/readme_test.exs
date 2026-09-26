# Validates the code snippets from README.md. Module bodies are copied from the
# README as verbatim as possible; only the parts marked `# ...` are filled in.

Application.put_env(:my_app, MyAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5002],
  url: [host: "localhost", port: 5002, scheme: "http"],
  server: false,
  secret_key_base: String.duplicate("a", 64),
  render_errors: [formats: [json: MyAppWeb.ErrorJSON], layout: false],
  adapter: Bandit.PhoenixAdapter
)

defmodule MyApp.Users do
  def list(opts) do
    send(self(), {:users_list_called, opts})
    [%{name: "Alice", email: "alice@example.com", nickname: nil}]
  end
end

defmodule MyAppWeb.ErrorJSON do
  def render(_template, assigns) do
    %{error: Exception.format(assigns.kind, assigns.reason, assigns.stack)}
  end
end

# -- README: my_app_web.ex ---------------------------------------------------

defmodule MyAppWeb do
  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]
      use Oaskit.Controller
      plug Oaskit.Plugs.ValidateRequest
      # ...
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes, endpoint: MyAppWeb.Endpoint, router: MyAppWeb.Router
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

# -- README: schema module ----------------------------------------------------

defmodule MyAppWeb.Schemas do
  use JSV.Schema

  defschema User,
    name: non_empty_string(),
    email: email(),
    # OpenAPI 3.1: a type union, no more `nullable: true`
    nickname: optional(%{type: [:string, :null]})
end

# -- README: controller -------------------------------------------------------

defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  # credo:disable-for-next-line Credo.Check.Readability.StrictModuleLayout
  alias MyAppWeb.Schemas.User

  # Parameters are validated and cast: `limit` is an integer here
  operation :index,
    parameters: [
      limit: [in: :query, schema: %{type: :integer, minimum: 1, maximum: 100}]
    ],
    responses: [ok: {%{type: :array, items: User}, []}]

  def index(conn, _params) do
    users = MyApp.Users.list(limit: query_param(conn, :limit, 20))
    json(conn, users)
  end

  # Using a schema module
  operation :create,
    request_body: User,
    responses: [created: User]

  def create(conn, _params) do
    %User{} = user = body_params(conn)
    # ...
    send(self(), {:create_body, user})
    conn |> put_status(201) |> json(user)
  end

  # Using an inline schema
  operation :update,
    parameters: [id: [in: :path, schema: %{type: :integer}]],
    request_body:
      {%{
         type: :object,
         properties: %{email: %{type: :string, format: :email}},
         required: [:email],
         additionalProperties: false
       }, required: true},
    responses: [ok: User]

  def update(conn, _params) do
    id = path_param(conn, :id)
    %{"email" => email} = body_params(conn)
    # ...
    send(self(), {:update_body, id, email})
    json(conn, %User{name: "Alice", email: email})
  end
end

# -- README: router ----------------------------------------------------------

defmodule MyAppWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec
  end

  scope "/api", MyAppWeb do
    pipe_through :api
    get "/users", UserController, :index
    post "/users", UserController, :create
    patch "/users/:id", UserController, :update
  end

  # README: serving the spec
  get "/openapi.json", Oaskit.SpecController, spec: MyAppWeb.ApiSpec
  get "/docs", Oaskit.SpecController, redoc: "/openapi.json"
end

defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug MyAppWeb.Router
end

# -- README: spec module ------------------------------------------------------

defmodule MyAppWeb.ApiSpec do
  alias Oaskit.Spec.Paths
  alias Oaskit.Spec.Server
  use Oaskit

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      info: %{title: "My App API", version: "1.0.0"},
      servers: [Server.from_config(:my_app, MyAppWeb.Endpoint)],
      paths: Paths.from_router(MyAppWeb.Router, filter: &String.starts_with?(&1.path, "/api/"))
    }
  end
end

# -- Tests --------------------------------------------------------------------

defmodule Oaskit.ReadmeTest do
  alias MyAppWeb.Schemas.User
  alias Oaskit.Test
  import Phoenix.ConnTest
  import Plug.Conn
  use ExUnit.Case, async: false
  use MyAppWeb, :verified_routes

  @endpoint MyAppWeb.Endpoint

  setup_all do
    start_supervised!(MyAppWeb.Endpoint)
    :ok
  end

  # Plain build_conn(), like a generated Phoenix ConnCase does.
  setup do
    {:ok, conn: build_conn()}
  end

  defp json_conn(conn \\ build_conn()) do
    put_req_header(conn, "content-type", "application/json")
  end

  defp valid_response(conn, status) do
    Test.valid_response(MyAppWeb.ApiSpec, conn, status)
  end

  test "spec is generated with the /api paths only" do
    spec = MyAppWeb.ApiSpec |> Oaskit.to_json!() |> IO.iodata_to_binary() |> JSON.decode!()

    assert Map.keys(spec["paths"]) |> Enum.sort() == ["/api/users", "/api/users/{id}"]
    assert [%{"url" => "http://localhost:5002/"}] = spec["servers"]

    assert [%{"name" => "id", "in" => "path", "required" => true}] =
             spec["paths"]["/api/users/{id}"]["patch"]["parameters"]

    assert %{"title" => "User", "required" => required} = spec["components"]["schemas"]["User"]
    assert Enum.sort(required) == ["email", "name"]
  end

  # README: test_example snippet, verbatim
  test "create user", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/users", %{name: "Alice", email: "alice@example.com"})

    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    assert %{"name" => "Alice"} = Oaskit.Test.valid_response(MyAppWeb.ApiSpec, conn, 201)
  end

  test "create user casts to the struct, which encodes to JSON", %{conn: conn} do
    conn = post(json_conn(conn), ~p"/api/users", %{name: "Alice", email: "alice@example.com"})

    assert %{"name" => "Alice", "nickname" => nil} =
             valid_response(conn, 201)

    assert_received {:create_body, %User{name: "Alice", nickname: nil}}

    conn =
      post(json_conn(), ~p"/api/users", %{name: "Bob", email: "bob@example.com", nickname: "b"})

    assert %{"nickname" => "b"} = valid_response(conn, 201)
  end

  test "index casts limit to integer and uses default", %{conn: conn} do
    conn1 = get(conn, ~p"/api/users?limit=5")
    assert [_] = valid_response(conn1, 200)
    assert_received {:users_list_called, [limit: 5]}

    conn2 = get(build_conn(), ~p"/api/users")
    assert [_] = valid_response(conn2, 200)
    assert_received {:users_list_called, [limit: 20]}
  end

  test "update casts the path param and gives string body keys", %{conn: conn} do
    conn = patch(json_conn(conn), ~p"/api/users/123", %{email: "a@b.com"})

    assert %{"email" => "a@b.com"} = valid_response(conn, 200)
    assert_received {:update_body, 123, "a@b.com"}
  end

  test "update rejects bad id, missing email and extra keys" do
    assert %{status: 400} = patch(json_conn(), ~p"/api/users/abc", %{email: "a@b.com"})
    assert %{status: 422} = patch(json_conn(), ~p"/api/users/1", %{})
    assert %{status: 422} = patch(json_conn(), ~p"/api/users/1", %{email: "a@b.com", x: 1})
  end

  test "error statuses: 400 for params, 422 for body, 415 for content type", %{conn: conn} do
    conn1 = get(conn, ~p"/api/users?limit=0")
    assert conn1.status == 400
    assert ["application/json" <> _] = get_resp_header(conn1, "content-type")

    conn2 = post(json_conn(), ~p"/api/users", %{name: ""})
    assert conn2.status == 422
    assert ["application/json" <> _] = get_resp_header(conn2, "content-type")

    conn3 =
      build_conn()
      |> put_req_header("content-type", "text/plain")
      |> post(~p"/api/users", "hello")

    assert conn3.status == 415
    assert ["application/json" <> _] = get_resp_header(conn3, "content-type")
  end

  test "spec controller and redoc", %{conn: conn} do
    conn1 = get(conn, "/openapi.json")
    assert %{"openapi" => "3.1.1"} = json_response(conn1, 200)

    conn2 = get(build_conn(), "/docs")
    assert html_response(conn2, 200) =~ "/openapi.json"
  end
end
