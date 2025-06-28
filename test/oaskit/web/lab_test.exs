defmodule Oaskit.Web.LabTest do
  alias Oaskit.TestWeb.DeclarativeApiSpec
  alias Oaskit.TestWeb.Schemas.CreatePotionBody
  alias Oaskit.TestWeb.Schemas.Ingredient
  import Oaskit.Test
  use Oaskit.ConnCase, async: true

  @valid_payload %{
    "name" => "Elixir of Vitality",
    "ingredients" => [
      %{
        "name" => "Phoenix Feather",
        "quantity" => 1,
        "unit" => "pinch"
      },
      %{
        "name" => "Dragon Scale",
        "quantity" => 2,
        "unit" => "dash"
      }
    ]
  }

  @invalid_payload_bad_unit %{
    "name" => "Elixir of Vitality",
    "ingredients" => [
      %{
        "name" => "Phoenix Feather",
        "quantity" => 1,
        # Invalid unit not in enum
        "unit" => "some bad unit"
      }
    ]
  }

  @invalid_payload_missing_name %{
    "ingredients" => [
      %{
        "name" => "Phoenix Feather",
        "quantity" => 1,
        "unit" => "pinch"
      }
    ]
  }

  @invalid_payload_missing_ingredients %{
    "name" => "Elixir of Vitality"
  }

  describe "create potion with valid data" do
    test "valid body and parameters are properly cast to structs", %{conn: conn} do
      conn =
        post_reply(
          conn,
          ~p"/provided/potions?dry_run=true&source=lab",
          @valid_payload,
          fn conn, _params ->
            # Check that the body is cast to the correct struct
            assert %CreatePotionBody{
                     name: "Elixir of Vitality",
                     ingredients: ingredients
                   } = conn.private.oaskit.body_params

            # Check that ingredients are properly cast to structs
            assert [
                     %Ingredient{
                       name: "Phoenix Feather",
                       quantity: 1,
                       unit: "pinch"
                     },
                     %Ingredient{
                       name: "Dragon Scale",
                       quantity: 2,
                       unit: "dash"
                     }
                   ] = ingredients

            # Check that query parameters are properly cast
            assert %{dry_run: true, source: "lab"} = conn.private.oaskit.query_params

            json(conn, %{data: "potion created"})
          end
        )

      assert %{"data" => "potion created"} = json_response(conn, 200)
    end

    test "boolean parameter casting when false", %{conn: conn} do
      conn =
        post_reply(
          conn,
          ~p"/provided/potions?dry_run=false",
          @valid_payload,
          fn conn, _params ->
            # Check that boolean parameter is properly cast
            assert %{dry_run: false} = conn.private.oaskit.query_params

            json(conn, %{data: "ok"})
          end
        )

      assert %{"data" => "ok"} = json_response(conn, 200)
    end

    test "with only required parameters", %{conn: conn} do
      conn =
        post_reply(
          conn,
          ~p"/provided/potions",
          @valid_payload,
          fn conn, _params ->
            # Optional parameters should not be present
            assert %{} = conn.private.oaskit.query_params

            json(conn, %{data: "ok"})
          end
        )

      assert %{"data" => "ok"} = json_response(conn, 200)
    end
  end

  describe "invalid request data returns proper errors" do
    test "invalid ingredient unit", %{conn: conn} do
      conn = post(conn, ~p"/provided/potions", @invalid_payload_bad_unit)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "createPotion",
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = json_response(conn, 422)
    end

    test "missing required field name", %{conn: conn} do
      conn = post(conn, ~p"/provided/potions", @invalid_payload_missing_name)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "createPotion",
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = json_response(conn, 422)
    end

    test "missing required field ingredients", %{conn: conn} do
      conn = post(conn, ~p"/provided/potions", @invalid_payload_missing_ingredients)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "createPotion",
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = json_response(conn, 422)
    end

    test "invalid query parameter type", %{conn: conn} do
      conn = post(conn, ~p"/provided/potions?dry_run=not-a-boolean", @valid_payload)

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "createPotion",
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter dry_run in query",
                     "parameter" => "dry_run",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = json_response(conn, 400)
    end

    test "body is parsed for application/json", %{conn: conn} do
      # as it is parsed, it should be JSON
      conn = post(conn, ~p"/provided/potions", nil)

      assert %{
               "error" => %{
                 "message" => "Unprocessable Entity",
                 "operation_id" => "createPotion",
                 "in" => "body",
                 "validation_error" => %{"valid" => false}
               }
             } = json_response(conn, 422)
    end

    @tag req_content_type: "foo/bar"
    test "body is not parsed for other content types", %{conn: conn} do
      # so as the body is  required we should have an error
      conn = post(conn, ~p"/provided/potions", nil)

      assert %{
               "error" => %{
                 "media_type" => "foo/bar",
                 "message" => "Unsupported Media Type",
                 "operation_id" => "createPotion"
               }
             } = json_response(conn, 415)
    end

    test "malformed JSON body", %{conn: conn} do
      # Test with malformed JSON - this should be caught by the parser before reaching our validation
      assert_raise Plug.Parsers.ParseError, fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> Phoenix.ConnTest.post(~p"/provided/potions", ~s({"name": "test", "malformed}))
      end
    end
  end

  describe "path item parameters" do
    # PathItem parameters are not supported with the operation macro:
    #
    # * At the controller level there is no guarantee that all routes belong to
    #   the same path.
    # * At the router level there is no practical mechanism to attach parameters
    #   to a scope.
    #
    # But it is supported when the spec is provided by other means (JSON, raw
    # Elixir data).

    @alchemists_page %{
      data: [
        %{
          name: "Merlin",
          titles: [
            "Enchanteur de Bretagne",
            "Grand vainqueur de la belette de Winchester",
            "Concepteur de la potion de guérison des ongles incarnés"
          ]
        },
        %{
          name: "Elias de Kelliwic'h",
          titles: [
            "Grand enchanteur du Nord",
            "Meneur des loups de Calédonie",
            "Pourfendeur du dragon des neiges"
          ]
        }
      ]
    }

    test "path parameters are collected", %{conn: conn} do
      conn =
        get_reply(
          conn,
          ~p"/provided/some-lab/alchemists",
          [q: "some search", page: 2, per_page: 10],
          fn
            conn, _params ->
              assert %{lab: "some-lab"} == conn.private.oaskit.path_params

              assert %{q: "some search", page: 2, per_page: 10} ==
                       conn.private.oaskit.query_params

              json(conn, @alchemists_page)
          end
        )

      assert %{"data" => [_, _]} = valid_response(DeclarativeApiSpec, conn, 200)
    end

    test "errors in pathitemparams", %{conn: conn} do
      conn = get(conn, ~p"/provided/some-lab/alchemists", q: "", page: 0, per_page: 0)

      assert %{
               "error" => %{
                 "in" => "parameters",
                 "kind" => "bad_request",
                 "message" => "Bad Request",
                 "operation_id" => "listAlchemists",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter page in query",
                     "parameter" => "page",
                     "validation_error" => _
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter per_page in query",
                     "parameter" => "per_page",
                     "validation_error" => _
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter q in query",
                     "parameter" => "q",
                     "validation_error" => _
                   }
                 ]
               }
             } = valid_response(DeclarativeApiSpec, conn, 400)
    end

    test "override of params", %{conn: conn} do
      # This route overrides the 'q' query param by allowing a min length of 0.
      # It also defines a query param 'lab' that does NOT override the 'lab'
      # path param.

      conn =
        post_reply(
          conn,
          ~p"/provided/some-lab/alchemists?q=&lab=someprefix:xxx",
          nil,
          fn
            conn, _params ->
              assert %{lab: "some-lab"} == conn.private.oaskit.path_params
              assert %{q: "", lab: "someprefix:xxx"} == conn.private.oaskit.query_params

              json(conn, @alchemists_page)
          end
        )

      assert %{"data" => [_, _]} = valid_response(DeclarativeApiSpec, conn, 200)
    end
  end
end
