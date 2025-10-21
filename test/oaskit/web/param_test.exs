defmodule Oaskit.Web.ParamTest do
  alias Oaskit.TestWeb.PathsApiSpec
  import Oaskit.Test
  use Oaskit.ConnCase, async: true

  describe "no params" do
    test "path_params and query_params is always defined", %{conn: conn} do
      conn =
        get_reply(
          conn,
          ~p"/generated/no-params",
          fn
            conn, _params ->
              # Default phoenix params are not changed

              assert %{} == conn.query_params
              assert %{} == conn.private.oaskit.path_params
              assert %{} == conn.private.oaskit.query_params
              assert %{} == conn.private.oaskit.body_params

              json(conn, %{data: "okay"})
          end
        )

      assert %{"data" => "okay"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  describe "single path param" do
    test "valid param", %{conn: conn} do
      conn =
        get_reply(conn, ~p"/generated/params/some-slug/t/dark", fn conn, _params ->
          assert %{theme: :dark} = conn.private.oaskit.path_params
          json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "invalid param", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/t/UNKNOWN_THEME")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_single_path_param" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter theme in path",
                     "parameter" => "theme",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end
  end

  describe "two path params (no scope)" do
    test "two invalid path params", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/BAD_SLUG/t/UNKNOWN_THEME/c/UNKNOWN_COLOR")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_two_path_params" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter color in path",
                     "parameter" => "color",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter slug in path",
                     "parameter" => "slug",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter theme in path",
                     "parameter" => "theme",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "one valid, one invalid path param", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/t/dark/c/UNKNOWN_COLOR")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_two_path_params" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter color in path",
                     "parameter" => "color",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "both valid path params", %{conn: conn} do
      conn =
        get_reply(conn, ~p"/generated/params/some-slug/t/dark/c/red", fn conn, _params ->
          assert %{theme: :dark, color: :red} = conn.private.oaskit.path_params
          json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  describe "scope and path params" do
    test "valid scope param, invalid path param", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/s/circle/t/UNKNOWN_THEME")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_scope_and_single" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter theme in path",
                     "parameter" => "theme",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "invalid scope param, valid path param", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/s/UNKNOWN_SHAPE/t/dark")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_scope_and_single" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter shape in path",
                     "parameter" => "shape",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "both scope and path params invalid", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/s/UNKNOWN_SHAPE/t/UNKNOWN_THEME")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_scope_and_single" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter shape in path",
                     "parameter" => "shape",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "path",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter theme in path",
                     "parameter" => "theme",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "both scope and path params valid", %{conn: conn} do
      conn =
        get_reply(conn, ~p"/generated/params/some-slug/s/square/t/light", fn conn, _params ->
          assert %{shape: :square, theme: :light} = conn.private.oaskit.path_params
          json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  # Query params on this route accept integers in 0..100
  describe "query params" do
    test "valid query params with integers", %{conn: conn} do
      conn =
        get_reply(
          conn,
          ~p"/generated/params/some-slug/s/square/t/light/c/red?shape=10&theme=20&color=30",
          fn
            conn, params ->
              # standard phoenix behaviour should not be changed, the path params have priority
              assert %{
                       "slug" => "some-slug",
                       "shape" => "square",
                       "theme" => "light",
                       "color" => "red"
                     } == params

              assert %{"shape" => "10", "theme" => "20", "color" => "30"} == conn.query_params

              # oaskit data is properly cast
              assert %{slug: "some-slug", shape: :square, theme: :light, color: :red} ==
                       conn.private.oaskit.path_params

              assert %{shape: 10, theme: 20, color: 30} == conn.private.oaskit.query_params

              json(conn, %{data: "okay"})
          end
        )

      assert %{"data" => "okay"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "invalid query params with too large integers", %{conn: conn} do
      # Ensures that our schemas for the query params are not overriden by the
      # schemas of the path params

      conn =
        get(
          conn,
          ~p"/generated/params/some-slug/s/square/t/light/c/red?shape=1010&theme=1020&color=1030"
        )

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_scope_and_two_path_params" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter color in query",
                     "parameter" => "color",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter shape in query",
                     "parameter" => "shape",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter theme in query",
                     "parameter" => "theme",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "invalid query params with same values as path", %{conn: conn} do
      # Ensures that our schemas for the query params are not overriden by the
      # schemas of the path params

      conn =
        get(
          conn,
          ~p"/generated/params/some-slug/s/square/t/light/c/red?shape=square&theme=light&color=red"
        )

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_scope_and_two_path_params" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter color in query",
                     "parameter" => "color",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter shape in query",
                     "parameter" => "shape",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter theme in query",
                     "parameter" => "theme",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "required query param is missing", %{conn: conn} do
      # The shape query param is required
      conn = get(conn, ~p"/generated/params/some-slug/s/square/t/light/c/red?theme=20&color=30")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_scope_and_two_path_params" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "missing_parameter",
                     "message" => "missing parameter shape in query",
                     "parameter" => "shape"
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "optional query params can be omitted", %{conn: conn} do
      # The shape query param is required, but other ones are not so we do not
      # give them.

      conn =
        get_reply(conn, ~p"/generated/params/some-slug/s/square/t/light/c/red?shape=10", fn
          conn, params ->
            # standard phoenix behaviour should not be changed, the path params have priority
            assert %{
                     "slug" => "some-slug",
                     "shape" => "square",
                     "theme" => "light",
                     "color" => "red"
                   } == params

            assert %{"shape" => "10"} == conn.query_params

            # oaskit data is properly cast
            assert %{shape: 10} == conn.private.oaskit.query_params

            json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  describe "controller helpers" do
    test "should return value from params", %{conn: conn} do
      conn =
        get_reply(conn, ~p"/generated/params/some-slug/s/square/t/light/c/red?shape=10", fn
          conn, _params ->
            import Oaskit.Controller

            assert "some-slug" == path_param(conn, :slug)
            assert :square == path_param(conn, :shape)
            assert :light == path_param(conn, :theme)
            assert :red == path_param(conn, :color)

            assert 10 == query_param(conn, :shape)

            assert nil == query_param(conn, :theme)
            assert :some_default == query_param(conn, :theme, :some_default)

            assert nil == query_param(conn, :color)
            assert :some_default == query_param(conn, :color, :some_default)

            json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  describe "generic parameter types" do
    test "valid parameters of different types", %{conn: conn} do
      conn =
        get_reply(
          conn,
          ~p"/generated/params/some-slug/generic?string_param=hello&boolean_param=true&integer_param=42&number_param=99",
          fn conn, params ->
            # Assert that Phoenix doesn't cast the parameters
            assert %{
                     "slug" => "some-slug",
                     "string_param" => "hello",
                     "boolean_param" => "true",
                     "integer_param" => "42",
                     "number_param" => "99"
                   } == params

            assert %{
                     "string_param" => "hello",
                     "boolean_param" => "true",
                     "integer_param" => "42",
                     "number_param" => "99"
                   } == conn.query_params

            # Assert that Oaskit properly casts the parameters
            assert %{
                     string_param: "hello",
                     boolean_param: true,
                     integer_param: 42,
                     number_param: 99
                   } == conn.private.oaskit.query_params

            json(conn, %{data: "ok"})
          end
        )

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "invalid parameters that cannot be cast", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/generated/params/some-slug/generic?string_param=hello&boolean_param=not-a-boolean&integer_param=not-a-number&number_param=not-a-number"
        )

      assert %{
               "error" => %{
                 "operation_id" => "param_generic_param_types" <> _,
                 "message" => "Bad Request",
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter boolean_param in query",
                     "parameter" => "boolean_param",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter integer_param in query",
                     "parameter" => "integer_param",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter number_param in query",
                     "parameter" => "number_param",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } =
               valid_response(PathsApiSpec, conn, 400)
    end
  end

  describe "array parameters" do
    test "valid array parameters", %{conn: conn} do
      # All parameters have a schema of array_of(integer()) and the validated
      # values should be [1,2,3]

      valid_array_parameters =
        [
          # simple form comma separated list
          "query__array__style_form__explode_false=1,2,3",

          # form exploded in multiple values
          "query__array__style_form__explode_true[]=1",
          "query__array__style_form__explode_true[]=2",
          "query__array__style_form__explode_true[]=3",

          # With delimiters when the list is not exploded in multiple query
          # params
          "query__array__style_spaceDelimited__explode_false=1%202%203",
          "query__array__style_pipeDelimited__explode_false=1|2|3",

          # With delimiters but exploded in multiple params the delimiter will
          # be ignored
          "query__array__style_spaceDelimited__explode_true[]=1",
          "query__array__style_spaceDelimited__explode_true[]=2",
          "query__array__style_spaceDelimited__explode_true[]=3",
          #
          "query__array__style_pipeDelimited__explode_true[]=1",
          "query__array__style_pipeDelimited__explode_true[]=2",
          "query__array__style_pipeDelimited__explode_true[]=3"
        ]
        |> Enum.join("&")

      conn =
        get_reply(
          conn,
          ~p"/generated/params/some-slug/arrays" <> "?" <> valid_array_parameters,
          fn conn, params ->
            # Assert that Phoenix doesn't cast the parameters

            assert %{
                     "slug" => "some-slug",
                     # Phoenix parses arrays automatically as we provided the
                     # [] suffix to param names
                     "query__array__style_form__explode_true" => ["1", "2", "3"],
                     "query__array__style_pipeDelimited__explode_true" => ["1", "2", "3"],
                     "query__array__style_spaceDelimited__explode_true" => ["1", "2", "3"],

                     # Parameters without the suffix are kept as strings
                     "query__array__style_form__explode_false" => "1,2,3",
                     "query__array__style_spaceDelimited__explode_false" => "1 2 3",
                     "query__array__style_pipeDelimited__explode_false" => "1|2|3"
                   } == params

            # Same in raw query params
            assert %{
                     # Phoenix parses arrays automatically as we provided the
                     # [] suffix to param names
                     "query__array__style_form__explode_true" => ["1", "2", "3"],
                     "query__array__style_pipeDelimited__explode_true" => ["1", "2", "3"],
                     "query__array__style_spaceDelimited__explode_true" => ["1", "2", "3"],

                     # Parameters without the suffix are kept as strings
                     "query__array__style_form__explode_false" => "1,2,3",
                     "query__array__style_spaceDelimited__explode_false" => "1 2 3",
                     "query__array__style_pipeDelimited__explode_false" => "1|2|3"
                   } == conn.query_params

            # Assert that Oaskit properly casts the arrays
            assert %{
                     query__array__style_form__explode_false: [1, 2, 3],
                     query__array__style_form__explode_true: [1, 2, 3],
                     query__array__style_pipeDelimited__explode_false: [1, 2, 3],
                     query__array__style_pipeDelimited__explode_true: [1, 2, 3],
                     query__array__style_spaceDelimited__explode_false: [1, 2, 3],
                     query__array__style_spaceDelimited__explode_true: [1, 2, 3]
                   } == conn.private.oaskit.query_params

            json(conn, %{data: "ok"})
          end
        )

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "invalid array parameters", %{conn: base_conn} do
      test_invalid_qs = fn qs ->
        conn = get(base_conn, ~p"/generated/params/some-slug/arrays" <> "?" <> qs)

        valid_response(PathsApiSpec, conn, 400)
      end

      assert_array_parameter_type_error = fn error, parameter ->
        assert %{
                 "error" => %{
                   "in" => "parameters",
                   "kind" => "bad_request",
                   "message" => "Bad Request",
                   "parameters_errors" => [
                     %{
                       "in" => "query",
                       "kind" => "invalid_parameter",
                       "parameter" => ^parameter,
                       "validation_error" => %{
                         "details" => [
                           %{
                             "errors" => [
                               %{
                                 "kind" => "type",
                                 "message" => "value is not of type integer"
                               }
                             ],
                             "valid" => false
                           },
                           %{
                             "errors" => [
                               %{
                                 "kind" => "items",
                                 "message" =>
                                   "item at index " <>
                                     <<_>> <> " does not validate the 'items' schema"
                               }
                             ],
                             "valid" => false
                           }
                         ],
                         "valid" => false
                       }
                     }
                   ]
                 }
               } = error
      end

      # # form exploded in multiple values
      # "query__array__style_form__explode_true[]=1",
      # "query__array__style_form__explode_true[]=2",
      # "query__array__style_form__explode_true[]=3",

      # # With delimiters when the list is not exploded in multiple query
      # # params
      # "query__array__style_spaceDelimited__explode_false=1%202%203",
      # "query__array__style_pipeDelimited__explode_false=1|2|3",

      # # With delimiters but exploded in multiple params the delimiter will
      # # be ignored
      # "query__array__style_spaceDelimited__explode_true[]=1",
      # "query__array__style_spaceDelimited__explode_true[]=2",
      # "query__array__style_spaceDelimited__explode_true[]=3",
      # #
      # "query__array__style_pipeDelimited__explode_true[]=1",
      # "query__array__style_pipeDelimited__explode_true[]=2",
      # "query__array__style_pipeDelimited__explode_true[]=3"

      # Explode false

      err = test_invalid_qs.("query__array__style_form__explode_false=1,not_an_int,3")
      assert_array_parameter_type_error.(err, "query__array__style_form__explode_false")

      err =
        test_invalid_qs.("query__array__style_spaceDelimited__explode_false=not_an_int%202%203")

      assert_array_parameter_type_error.(err, "query__array__style_spaceDelimited__explode_false")

      err = test_invalid_qs.("query__array__style_pipeDelimited__explode_false=1|2|not_an_int")
      assert_array_parameter_type_error.(err, "query__array__style_pipeDelimited__explode_false")

      # Explode true

      err =
        test_invalid_qs.(
          "query__array__style_form__explode_true[]=1&" <>
            "query__array__style_form__explode_true[]=not_an_int&" <>
            "query__array__style_form__explode_true[]=3"
        )

      assert_array_parameter_type_error.(err, "query__array__style_form__explode_true")

      err =
        test_invalid_qs.(
          "query__array__style_spaceDelimited__explode_true[]=1&" <>
            "query__array__style_spaceDelimited__explode_true[]=not_an_int&" <>
            "query__array__style_spaceDelimited__explode_true[]=3"
        )

      assert_array_parameter_type_error.(err, "query__array__style_spaceDelimited__explode_true")

      err =
        test_invalid_qs.(
          "query__array__style_pipeDelimited__explode_true[]=1&" <>
            "query__array__style_pipeDelimited__explode_true[]=not_an_int&" <>
            "query__array__style_pipeDelimited__explode_true[]=3"
        )

      assert_array_parameter_type_error.(err, "query__array__style_pipeDelimited__explode_true")
    end

    test "non-array parameter when array expected", %{conn: conn} do
      # This works with explode: true because Phoenix/Plug are supposed to
      # provide a list.
      #
      # This is also a shortcomming of Oaskit: with array schemas it can only
      # support parameters with the `[]` suffix.
      conn =
        get(
          conn,
          ~p"/generated/params/some-slug/arrays" <>
            "?" <> "query__array__style_form__explode_true=123"
        )

      assert %{
               "error" => %{
                 "operation_id" => "param_array_types" <> _,
                 "message" => "Bad Request",
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" =>
                       "invalid parameter query__array__style_form__explode_true in query",
                     "parameter" => "query__array__style_form__explode_true",
                     "validation_error" => _
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "array parameters sent to non-array route", %{conn: conn} do
      # Sending array parameters to the generic param route which expects scalar types
      conn =
        get(conn, ~p"/generated/params/some-slug/generic?string_param[]=hello&integer_param[]=42")

      assert %{
               "error" => %{
                 "operation_id" => "param_generic_param_types" <> _,
                 "message" => "Bad Request",
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter integer_param in query",
                     "parameter" => "integer_param",
                     "validation_error" => _
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter string_param in query",
                     "parameter" => "string_param",
                     "validation_error" => _
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "array parameters with explicit brackets in controller definition", %{conn: conn} do
      # This test verifies that parameters defined with [] in controller work correctly
      # and that the OpenAPI spec generation handles bracket normalization

      # First, let's test that the existing array_types endpoint works with the Phoenix format
      conn =
        get_reply(
          conn,
          ~p"/generated/params/some-slug/arrays?numbers[]=789&numbers[]=101112&names[]=Charlie&names[]=Delta",
          fn conn, _params ->
            # Phoenix should parse brackets correctly
            assert %{
                     "numbers" => ["789", "101112"],
                     "names" => ["Charlie", "Delta"]
                   } == conn.query_params

            # Oaskit should cast and store without brackets in the internal key
            assert %{
                     numbers: [789, 101_112],
                     names: ["Charlie", "Delta"]
                   } == conn.private.oaskit.query_params

            json(conn, %{data: "brackets_handled"})
          end
        )

      assert %{"data" => "brackets_handled"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "OpenAPI spec generation includes brackets for array query parameters" do
      # Test that the generated OpenAPI spec has the correct parameter names with brackets
      spec = Oaskit.cast!(PathsApiSpec)

      # Find the array_types operation
      array_operation =
        spec.paths
        |> Enum.find_value(fn {_path, path_item} ->
          Enum.find_value(path_item, fn {_verb, operation} ->
            if operation.operationId =~ "array_types" do
              operation
            end
          end)
        end)

      assert array_operation, "Could not find array_types operation"

      # Check that array parameters have brackets in the OpenAPI spec
      parameter_names = Enum.map(array_operation.parameters, & &1.name)

      # Array query parameters should have brackets in the OpenAPI spec
      assert "numbers[]" in parameter_names
      assert "names[]" in parameter_names
    end

    test "handles parameters defined with explicit brackets in controller", %{conn: conn} do
      # Test the second requirement: handle parameters that already have brackets
      # in their controller definition. This simulates external OpenAPI document usage.

      conn =
        get_reply(
          conn,
          ~p"/generated/params/some-slug/explicit-brackets?users[]=Alice&users[]=Bob&ids[]=1&ids[]=2",
          fn conn, _params ->
            # Phoenix should parse brackets correctly
            assert %{
                     "users" => ["Alice", "Bob"],
                     "ids" => ["1", "2"]
                   } == conn.query_params

            # Oaskit should cast and store with clean keys (brackets removed)
            assert %{
                     users: ["Alice", "Bob"],
                     ids: [1, 2]
                   } == conn.private.oaskit.query_params

            json(conn, %{data: "explicit_brackets_handled"})
          end
        )

      assert %{"data" => "explicit_brackets_handled"} = valid_response(PathsApiSpec, conn, 200)

      # Verify OpenAPI spec shows brackets for these parameters too
      spec = Oaskit.cast!(PathsApiSpec)

      explicit_operation =
        spec.paths
        |> Enum.find_value(fn {_path, path_item} ->
          Enum.find_value(path_item, fn {_verb, operation} ->
            if operation.operationId =~ "explicit_brackets" do
              operation
            end
          end)
        end)

      assert explicit_operation, "Could not find explicit_brackets operation"
      parameter_names = Enum.map(explicit_operation.parameters, & &1.name)

      # Parameters should show brackets in OpenAPI spec
      assert "users[]" in parameter_names
      assert "ids[]" in parameter_names
    end

    test "with module schemas", %{conn: conn} do
      # Test that module schemas defining arrays are handled correctly
      conn =
        get_reply(
          conn,
          ~p"/generated/params/some-slug/module-arrays?numbers[]=1.5&numbers[]=2.7&numbers[]=3.14",
          fn conn, _params ->
            # Phoenix should parse brackets correctly
            assert %{
                     "numbers" => ["1.5", "2.7", "3.14"]
                   } == conn.query_params

            # Oaskit should cast and store with clean keys
            assert %{
                     numbers: [1.5, 2.7, 3.14]
                   } == conn.private.oaskit.query_params

            json(conn, %{data: "module_arrays_handled"})
          end
        )

      assert %{"data" => "module_arrays_handled"} = valid_response(PathsApiSpec, conn, 200)

      # Verify OpenAPI spec shows brackets for module array schema parameters
      spec = Oaskit.cast!(PathsApiSpec)
      module_operation = spec.paths
                        |> Enum.find_value(fn {_path, path_item} ->
                          Enum.find_value(path_item, fn {_verb, operation} ->
                            if operation.operationId =~ "array_types_with_module" do
                              operation
                            end
                          end)
                        end)

      assert module_operation, "Could not find array_types_with_module operation"
      parameter_names = Enum.map(module_operation.parameters, & &1.name)

      # Module array schema parameters should show brackets in OpenAPI spec
      assert "numbers[]" in parameter_names
    end
  end

  describe "boolean schema false in query params" do
    test "any query param value should be rejected with boolean schema false", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/boolean-schema-false?reject_me=any_value")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_boolean_schema_false" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter reject_me in query",
                     "parameter" => "reject_me",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "empty string query param should be rejected with boolean schema false", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/boolean-schema-false?reject_me=")

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_boolean_schema_false" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter reject_me in query",
                     "parameter" => "reject_me",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "multiple query params should all be rejected with boolean schema false", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/generated/params/some-slug/boolean-schema-false?reject_me=value1&also_reject=value2"
        )

      assert %{
               "error" => %{
                 "message" => "Bad Request",
                 "operation_id" => "param_boolean_schema_false" <> _,
                 "in" => "parameters",
                 "parameters_errors" => [
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter also_reject in query",
                     "parameter" => "also_reject",
                     "validation_error" => %{"valid" => false}
                   },
                   %{
                     "in" => "query",
                     "kind" => "invalid_parameter",
                     "message" => "invalid parameter reject_me in query",
                     "parameter" => "reject_me",
                     "validation_error" => %{"valid" => false}
                   }
                 ]
               }
             } = valid_response(PathsApiSpec, conn, 400)
    end

    test "no query params should be accepted with boolean schema false", %{conn: conn} do
      conn =
        get_reply(conn, ~p"/generated/params/some-slug/boolean-schema-false", fn conn, _params ->
          # No query params should be set or an empty map
          assert conn.private.oaskit.query_params == %{}

          json(conn, %{data: "ok"})
        end)

      assert %{"data" => "ok"} = valid_response(PathsApiSpec, conn, 200)
    end
  end

  describe "html error rendering" do
    @describetag [req_accept: "text/html"]

    test "required query param is missing HTML", %{conn: conn} do
      # The shape query param is required
      conn = get(conn, ~p"/generated/params/some-slug/s/square/t/light/c/red?theme=20&color=30")

      body = response(conn, 400)
      assert body =~ ~r{<!doctype html>.+Bad Request}s

      assert body =~
               ~r{<p>Invalid request for operation <code>param_scope_and_two_path_params_.+</code>.</p>}s

      assert body =~
               ~r{<h2>Missing required parameter <code>shape</code> in <code>query</code>\.</h2>}s

      assert body =~
               "<h2>Missing required parameter <code>shape</code> in <code>query</code>.</h2>"
    end

    test "invalid param text errors", %{conn: conn} do
      conn = get(conn, ~p"/generated/params/some-slug/t/UNKNOWN_THEME")

      body = response(conn, 400)
      assert body =~ ~r{<!doctype html>.+Bad Request}s

      assert body =~
               ~r{<p>Invalid request for operation <code>param_single_path_param_.+</code>.</p>}s

      assert body =~ ~r{<h2>Invalid parameter <code>theme</code> in <code>path</code>\.</h2>}s
      assert body =~ "<h2>Invalid parameter <code>theme</code> in <code>path</code>.</h2>"
      assert body =~ ~S(value must be one of the enum values: "dark" or "light")
    end
  end
end
