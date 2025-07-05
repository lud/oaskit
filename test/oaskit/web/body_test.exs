defmodule Oaskit.Web.BodyTest do
  alias Oaskit.TestWeb.PathsApiSpec
  alias Oaskit.TestWeb.Schemas.PlantSchema
  import Oaskit.Test
  use Oaskit.ConnCase, async: true

  @valid_payload %{
    "name" => "Monstera Deliciosa",
    "sunlight" => "bright_indirect"
  }

  @invalid_payload %{
    "name" => "Bird of Paradise",
    "sunlight" => "SOME INVALID SUNLIGHT"
  }

  @invalid_sub %{
    "name" => "Bird of Paradise",
    "sunlight" => "bright_indirect",
    "soil" => %{"acid" => true, "density" => "NOT A NUMBER"}
  }

  # Phoenix.ConnTest.post defaults to nil when no payload is provided
  @no_payload nil

  describe "boolean schema false" do
    test "any body should be rejected with boolean schema false", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/boolean-schema-false", @valid_payload)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "body_boolean_schema_false" <> _,
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = valid_response(PathsApiSpec, conn, 422)
    end

    test "non required body should be ok when body is empty", %{conn: conn} do
      # This works only because the route accepts content type */*
      conn =
        post_reply(conn, ~p"/generated/body/boolean-schema-false", @no_payload, fn
          conn, _params ->
            json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  describe "inline schema" do
    test "valid body", %{conn: conn} do
      conn =
        post_reply(conn, ~p"/generated/body/inline-single", @valid_payload, fn conn, _params ->
          import Oaskit.Controller

          assert %{"name" => "Monstera Deliciosa", "sunlight" => :bright_indirect} ==
                   body_params(conn)

          json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "invalid body", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/inline-single", @invalid_payload)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "body_inline_single" <> _,
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = valid_response(PathsApiSpec, conn, 422)
    end

    @tag req_content_type: "application/x-www-form-urlencoded"
    test "invalid content type returns 415 Unsupported Media Type in JSON format", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/inline-single", URI.encode_query(a: 1, b: 2))

      assert %{
               "error" => %{
                 "message" => "Unsupported Media Type",
                 "media_type" => "application/x-www-form-urlencoded"
               }
             } =
               valid_response(PathsApiSpec, conn, 415)
    end
  end

  describe "module-based schema" do
    # Same test as before but the schema is given as a module
    test "valid body", %{conn: conn} do
      conn =
        post_reply(conn, ~p"/generated/body/module-single", @valid_payload, fn
          conn, _params ->
            import Oaskit.Controller

            assert %PlantSchema{
                     name: "Monstera Deliciosa",
                     sunlight: :bright_indirect
                   } = body_params(conn)

            json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "invalid body", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/module-single", @invalid_payload)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "custom_operation_id_module_single",
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = valid_response(PathsApiSpec, conn, 422)
    end

    test "invalid body in sub schema", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/module-single", @invalid_sub)

      # schema locations should be in #/components/schemas/...
      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "custom_operation_id_module_single",
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = valid_response(PathsApiSpec, conn, 422)
    end
  end

  describe "form data" do
    @describetag req_content_type: "application/x-www-form-urlencoded"
    test "valid body", %{conn: conn} do
      form_data = URI.encode_query(@valid_payload)

      conn =
        post_reply(conn, ~p"/generated/body/form", form_data, fn conn, _params ->
          text(conn, "ok")
        end)

      assert "ok" = response(conn, 200)
    end
  end

  describe "undefined operation" do
    # When an operation is not defined but the plug is called, it will log a
    # warning.
    test "nothing is validated and nothing is logged", %{conn: conn} do
      io =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          payload = ~s({"some":"stuff"})

          conn =
            post_reply(conn, ~p"/generated/body/undefined-operation", payload, fn conn, _params ->
              text(conn, "ok")
            end)

          assert "ok" == response(conn, 200)
        end)

      assert io =~
               "Controller Oaskit.TestWeb.BodyController has no operation defined for action :undefined_operation"
    end
  end

  describe "ignored action" do
    test "no logs are output if an action has an explicit false operation", %{conn: conn} do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          payload = ~s({"some":"stuff"})

          conn =
            post_reply(conn, ~p"/generated/body/ignored-action", payload, fn conn, _params ->
              text(conn, "ok")
            end)

          assert "ok" == response(conn, 200)
        end)

      refute log =~ "BodyController"
    end
  end

  describe "wildcard content types" do
    @tag req_content_type: "test/test"
    test "wildcard take any content type", %{conn: conn} do
      # schema with wildcard content type is just `false`, so it should reject
      # everything BUT as the content-type does not tell that it's JSON or a
      # form, no parsing is done.

      # the test/test content type has a custom parser that will just copy the
      # raw body into conn.body_params
      conn = post(conn, ~p"/generated/body/wildcard", "some payload")

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "body_wildcard_media_type" <> _,
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = valid_response(PathsApiSpec, conn, 422)
    end

    test "wildcard does not take priority over more specific content types", %{conn: conn} do
      # the route exposes the regular PlantSchema for application/json
      conn =
        post_reply(conn, ~p"/generated/body/wildcard", @valid_payload, fn conn, _params ->
          json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  describe "non-required body" do
    test "empty body is accepted", %{conn: conn} do
      # schema with wildcard content type is just `false`
      conn =
        post_reply(conn, ~p"/generated/body/module-single-no-required", @no_payload, fn
          conn, _params ->
            # No content is set but the body_params key is always defined. Instead
            # of an empty map it is set to nil
            assert nil == conn.private.oaskit.body_params

            import Oaskit.Controller
            assert nil == body_params(conn)

            json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "valid body is parsed as usual", %{conn: conn} do
      # schema with wildcard content type is just `false`
      conn =
        post_reply(conn, ~p"/generated/body/module-single-no-required", @valid_payload, fn
          conn, _params ->
            assert %PlantSchema{
                     name: "Monstera Deliciosa",
                     sunlight: :bright_indirect
                   } = conn.private.oaskit.body_params

            json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "invalid body still returns an error", %{conn: conn} do
      # schema with wildcard content type is just `false`
      conn = post(conn, ~p"/generated/body/module-single-no-required", @invalid_payload)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "body_module_single_not_required" <> _,
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = valid_response(PathsApiSpec, conn, 422)
    end
  end

  describe "html error rendering" do
    @describetag req_accept: "text/html"

    test "invalid body returns HTML error for InvalidBodyError", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/inline-single", @invalid_payload)

      body = response(conn, 422)
      assert body =~ ~r{<!doctype html>.+Unprocessable Entity}s
      assert body =~ "<h2>Invalid request body.</h2>"
    end

    test "invalid body in module schema returns HTML error", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/module-single", @invalid_payload)

      body = response(conn, 422)
      assert body =~ ~r{<!doctype html>.+Unprocessable Entity}s
      assert body =~ "<h2>Invalid request body.</h2>"
    end

    test "invalid body in sub schema returns HTML error", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/module-single", @invalid_sub)

      body = response(conn, 422)
      assert body =~ ~r{<!doctype html>.+Unprocessable Entity}s
      assert body =~ "<h2>Invalid request body.</h2>"
    end

    @tag req_content_type: "application/x-www-form-urlencoded"
    test "unsupported media type returns HTML error for UnsupportedMediaTypeError", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/inline-single", URI.encode_query(a: 1, b: 2))

      body = response(conn, 415)
      assert body =~ ~r{<!doctype html>.+Unsupported Media Type}s
      assert body =~ ~r{<p>Invalid request for operation <code>body_inline_single_.+</code>.</p>}s

      assert body =~
               ~r{<h2>Validation for body of type <code>application/x-www-form-urlencoded</code> is not supported\.</h2>}s

      assert body =~
               "<h2>Validation for body of type <code>application/x-www-form-urlencoded</code> is not supported.</h2>"
    end

    @tag req_content_type: "application/x-www-form-urlencoded"
    test "form data with invalid body returns HTML error", %{conn: conn} do
      conn = post(conn, ~p"/generated/body/form", @invalid_payload)

      body = response(conn, 422)
      assert body =~ ~r{<!doctype html>.+Unprocessable Entity}s
      assert body =~ ~r{<p>Invalid request for operation <code>body_handle_form_.+</code>.</p>}s
      assert body =~ "<h2>Invalid request body.</h2>"
    end
  end
end
