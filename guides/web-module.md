# API Controllers in Web module

This guide explains how the `MyAppWeb` module ties your Phoenix application
together, and how to use it to separate "normal" controllers (serving HTML
pages, for instance) from controllers that implement an HTTP API validated by
Oaskit.



## How `use MyAppWeb, :controller` works

> ### Skip this section… {: .tip}
>
> If you are already comfortable with how `use MyAppWeb, :controller` works, you can jump
> directly to [Why a dedicated API controller?](#why-a-dedicated-api-controller).


When you generate a Phoenix application, a module named after your web layer is
created, generally in `lib/my_app_web.ex`. This is the `MyAppWeb` module, and it
is the central place where the boilerplate for all the "web" building blocks
lives: controllers, HTML views, components, LiveViews, channels, the router,
_etc._

Every one of those building blocks starts with the same line:

```elixir
use MyAppWeb, :controller
# or
use MyAppWeb, :html
# or
use MyAppWeb, :live_view
```

That second argument is just an atom. When you write `use MyAppWeb,
:controller`, Elixir calls the `__using__/1` macro of the `MyAppWeb` module with
`:controller` as the argument. The generated implementation simply dispatches to
a function of the same name:

<!-- rdmx :section name:using_dispatch format: true -->
```elixir
defmodule MyAppWeb do
  # ...

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: MyAppWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: MyAppWeb.Gettext

      unquote(verified_routes())
    end
  end

  # Dispatches `use MyAppWeb, :controller` to the `controller/0` function above,
  # `use MyAppWeb, :html` to `html/0`, and so on.
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
```
<!-- rdmx /:section -->

In other words, `use MyAppWeb, :controller` is just a shortcut that injects
whatever the `controller/0` function returns. The same mechanism is used for
`:html`, `:live_view`, `:channel`, `:router`, and any other name you care to
add.

This is the key insight for the rest of this guide: **you are free to define new
entry points**. Nothing forces you to only have `:controller`. You can add an
`:api_controller` function, and every module that calls `use MyAppWeb,
:api_controller` will receive that specific setup.


## Why a dedicated API controller?

The [Quickstart](quickstart.md) guide shows the simplest setup, where
`use Oaskit.Controller` and the `Oaskit.Plugs.ValidateRequest` plug are added
directly to the `controller/0` function. That works well when **all** your
controllers belong to your HTTP API.

But many applications mix concerns:

* Controllers that render HTML pages (a marketing site, an admin dashboard,
  authentication flows, _etc._).
* Controllers that implement a JSON API meant to be validated against an OpenAPI
  specification.

You generally do not want request validation on the HTML controllers. When the
`Oaskit.Plugs.ValidateRequest` plug runs on an action that has no matching
operation, it lets the request through untouched and logs a warning to remind
you that the action is not described in your specification.

That warning is harmless and easy to silence: you can explicitly mark an action
as not validated by passing `false` to the `operation` macro.

```elixir
operation :home, false

def home(conn, _params) do
  # ...
end
```

This is handy for the occasional non-API action inside an otherwise validated
controller. But adding such a declaration to every action of every HTML
controller quickly becomes noise. The cleaner solution is to keep the regular
`controller/0` function untouched for your HTML controllers, and add a separate
`api_controller/0` function for the controllers that belong to your API. That
way the validation plug only runs where operations are actually defined.


## Defining an API controller

Add an `api_controller/0` function to your `MyAppWeb` module. It mirrors the
regular `controller/0` function but adds the two Oaskit pieces:

* `use Oaskit.Controller` to bring in the `operation/2`, `use_operation/2` and
  other macros.
* `plug Oaskit.Plugs.ValidateRequest` to validate incoming requests against the
  declared operations.

The two functions share a bit of common setup. You could factor that into a
private helper, but a small amount of duplication keeps each entry point
self-contained and easy to read, so we simply repeat the shared lines:

<!-- rdmx :section name:api_controller_def format: true -->
```elixir
defmodule MyAppWeb do
  # "Normal" controllers, serving HTML and other formats. No validation.
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: MyAppWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: MyAppWeb.Gettext

      unquote(verified_routes())
    end
  end

  # API controllers, validated by Oaskit.
  def api_controller do
    quote do
      # JSON only, and no HTML layout for an API.
      use Phoenix.Controller, formats: [:json]

      # Bring in the Oaskit macros (operation/2, use_operation/2, ...).
      use Oaskit.Controller

      # Validate every request handled by these controllers. This must come
      # after `use Phoenix.Controller`.
      plug Oaskit.Plugs.ValidateRequest

      import Plug.Conn
      use Gettext, backend: MyAppWeb.Gettext

      unquote(verified_routes())
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
```
<!-- rdmx /:section -->

Now your HTML controllers keep using the regular helper:

<!-- rdmx :section name:html_controller_use format: true -->
```elixir
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  # No operations, no validation. Just a regular Phoenix controller.
  def home(conn, _params) do
    render(conn, :home)
  end
end
```
<!-- rdmx /:section -->

And your API controllers opt into validation by using the new helper:

<!-- rdmx :section name:api_controller_use format: true -->
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :api_controller

  operation :create,
    summary: "Create a new user",
    request_body: MyAppWeb.Schemas.UserSchema,
    responses: [created: MyAppWeb.Schemas.UserSchema]

  def create(conn, _params) do
    user_data = body_params(conn)
    # ...
  end
end
```
<!-- rdmx /:section -->


## Two plugs, two places

Oaskit validation relies on two plugs that live in different places, and it is
worth understanding why.

* `Oaskit.Plugs.SpecProvider` goes in a **router pipeline**, as shown in the
  [Quickstart](quickstart.md). It simply records which specification module to
  validate against on the conn, which the router pipeline is a natural place for.
* `Oaskit.Plugs.ValidateRequest` goes in a **controller**, as in the
  `api_controller/0` function above. It performs the actual validation.

`ValidateRequest` must run from a controller because it needs to know the
operation to validate against, and that is derived from the matched Phoenix
controller and action. Phoenix only sets `phoenix_controller` and
`phoenix_action` on the conn when it dispatches to the controller, which happens
*after* the router pipelines have run. Plugging `ValidateRequest` into a router
pipeline would run it too early, before the route is resolved, and it would
raise.

Plugging it in the `api_controller/0` function is therefore both the correct and
the most convenient approach: only controllers that use `:api_controller` are
validated, which is exactly what you want when you have a mix of HTML and API
controllers.


## Going further

If you have several APIs (for instance a public API and an internal one, or
versioned APIs), keep in mind that **which specification a request is validated
against is not decided in the controller**. That choice belongs to the router,
where the `Oaskit.Plugs.SpecProvider` plug records the spec module on the conn
for a given router pipeline.

A direct consequence is that a single `api_controller/0` is usually enough: the
same controller can be served from several routes under different pipelines, and
therefore validated against different specifications. For example, the same
`UserController` could be exposed under both a public spec and an internal spec
just by routing it through two pipelines that each provide a different spec
module.

Defining several controller entry points is still useful, but for
*controller-level* concerns rather than spec selection, for instance a different
error handler, different response formats, or additional plugs:

<!-- rdmx :section name:multiple_apis format: true -->
```elixir
def api_controller do
  quote do
    use Phoenix.Controller, formats: [:json]
    use Oaskit.Controller
    plug Oaskit.Plugs.ValidateRequest

    import Plug.Conn
    use Gettext, backend: MyAppWeb.Gettext
    unquote(verified_routes())
  end
end

def admin_api_controller do
  quote do
    use Phoenix.Controller, formats: [:json]
    use Oaskit.Controller
    plug Oaskit.Plugs.ValidateRequest, error_handler: MyAppWeb.AdminErrorHandler

    import Plug.Conn
    use Gettext, backend: MyAppWeb.Gettext
    unquote(verified_routes())
  end
end
```
<!-- rdmx /:section -->

Each controller then picks the entry point it needs with `use MyAppWeb,
:api_controller` or `use MyAppWeb, :admin_api_controller`, while the router
decides the specification.
