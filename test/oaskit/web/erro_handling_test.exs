defmodule Oaskit.Web.ErroHandlingTest do
  use Oaskit.ConnCase, async: true

  describe "html errors can be disabled" do
    # The controller is using `html_errors: false` for the validation plug so we
    # should have only json errors despite the HTTP request accepting HTML.
    @describetag req_accept: "text/html"

    @invalid_payload %{}
    @invalid_form "name=foo"
    @valid_payload %{
      "name" => "Monstera Deliciosa",
      "sunlight" => "bright_indirect"
    }

    test "invalid payload returns JSON error", %{conn: conn} do
      conn = post(conn, ~p"/generated/no-html-errors?an_int=123", @invalid_payload)

      assert %{"error" => %{"in" => "body", "kind" => "unprocessable_entity"}} =
               json_response(conn, 422)
    end

    @tag req_content_type: "application/x-www-form-urlencoded"
    test "invalid form returns JSON error", %{conn: conn} do
      # Even when asking with a form, we are returning JSON
      conn = post(conn, ~p"/generated/no-html-errors?an_int=123", @invalid_form)

      assert %{"error" => %{"in" => "body", "kind" => "unprocessable_entity"}} =
               json_response(conn, 422)
    end

    # unknown content type
    @tag req_content_type: "application/foo"
    test "unsupported media type returns JSON error", %{conn: conn} do
      conn = post(conn, ~p"/generated/no-html-errors?an_int=123", @invalid_form)

      assert %{"error" => %{"in" => "body", "kind" => "unsupported_media_type"}} =
               json_response(conn, 415)
    end

    test "invalid parameter returns JSON error", %{conn: conn} do
      conn = post(conn, ~p"/generated/no-html-errors?an_int=not-an-int", @valid_payload)

      assert %{
               "error" => %{
                 "in" => "parameters",
                 "kind" => "bad_request",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter an_int in query",
                     "parameter" => "an_int",
                     "validation_error" => _
                   }
                 ]
               }
             } =
               json_response(conn, 400)
    end

    test "missing parameter returns JSON error", %{conn: conn} do
      conn = post(conn, ~p"/generated/no-html-errors", @valid_payload)

      assert %{
               "error" => %{
                 "in" => "parameters",
                 "kind" => "bad_request",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "missing_parameter",
                     "parameter" => "an_int"
                   }
                 ]
               }
             } =
               json_response(conn, 400)
    end
  end
end
