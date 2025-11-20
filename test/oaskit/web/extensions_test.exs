defmodule Oaskit.Web.ExtensionsTest do
  alias JSV.Codec
  alias Oaskit.TestWeb.PathsApiSpec
  import Oaskit.Test
  use Oaskit.ConnCase, async: true

  describe "basic extensions" do
    test "encodable extensions are provided", %{conn: conn} do
      conn =
        get_reply(
          conn,
          ~p"/generated/extensions/with-json-encodable-ext",
          fn
            conn, _params ->
              # Atom form is preserved
              assert %{some_extension: "hello"} == conn.private.oaskit.extensions

              json(conn, %{data: "okay"})
          end
        )

      assert %{"data" => "okay"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "public and private extensions are provided", %{conn: conn} do
      conn =
        get_reply(
          conn,
          ~p"/generated/extensions/with-public-and-private",
          fn
            conn, _params ->
              # All extensions are preserved, but only public (x- prefixed)
              # extensions should be exported in JSON documents.
              assert %{"private-ext": "some private", "x-public-ext": "some public"} ==
                       conn.private.oaskit.extensions

              assert %{
                       "paths" => %{
                         "/generated/extensions/with-public-and-private" => %{"get" => json_op}
                       }
                     } =
                       PathsApiSpec
                       |> Oaskit.to_json!()
                       |> Codec.decode!()

              assert is_map_key(json_op, "x-public-ext")
              refute is_map_key(json_op, "private-ext")

              json(conn, %{data: "okay"})
          end
        )

      assert %{"data" => "okay"} = valid_response(PathsApiSpec, conn, 200)
    end

    test "non json encodable can be given as private extensions", %{conn: conn} do
      conn =
        get_reply(
          conn,
          ~p"/generated/extensions/with-struct",
          fn
            conn, _params ->
              assert %{
                       "private-struct": %Oaskit.TestWeb.ExtensionController.SomeStruct{foo: :bar}
                     } ==
                       conn.private.oaskit.extensions

              assert %{
                       "paths" => %{
                         "/generated/extensions/with-public-and-private" => %{"get" => json_op}
                       }
                     } =
                       PathsApiSpec
                       |> Oaskit.to_json!()
                       |> Codec.decode!()

              assert is_map_key(json_op, "x-public-ext")
              refute is_map_key(json_op, "private-ext")

              json(conn, %{data: "okay"})
          end
        )

      assert %{"data" => "okay"} = valid_response(PathsApiSpec, conn, 200)
    end
  end
end
