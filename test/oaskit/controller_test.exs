defmodule Oaskit.ControllerTest do
  alias Oaskit.Spec.MediaType
  alias Oaskit.Spec.Operation
  alias Oaskit.Spec.RequestBody
  use ExUnit.Case, async: true

  defmodule SomeSchema do
    use JSV.Schema
    defschema(props(a: integer()))
  end

  test "define with inline request body schema" do
    spec = [
      operation_id: :some_operation,
      # passing a map as the request body is handled as a schema. we should
      # have a default content type of application/json associated with this
      # schema.
      request_body: {%{type: :string}, []},
      tags: [:a, :b],
      description: "some description",
      summary: "some summary",
      responses: [ok: true]
    ]

    op = Operation.from_controller!(spec)

    assert %Operation{
             description: "some description",
             summary: "some summary",
             operationId: :some_operation,
             tags: [:a, :b],
             requestBody: %RequestBody{
               content: %{
                 "application/json" => %MediaType{
                   schema: %{type: :string}
                 }
               }
             }
           } = op
  end

  describe "required body" do
    test "when using shortcut, body is required by default" do
      # spec with a direct schema is required
      spec0 = [operation_id: :some_operation, request_body: SomeSchema, responses: [ok: true]]
      op0 = Operation.from_controller!(spec0)
      assert %Operation{requestBody: %RequestBody{required: true}} = op0

      # spec with a schema and options is required
      spec1 = [
        operation_id: :some_operation,
        request_body: {SomeSchema, []},
        responses: [ok: true]
      ]

      op1 = Operation.from_controller!(spec1)
      assert %Operation{requestBody: %RequestBody{required: true}} = op1

      # spec with a schema and options can be made non-required
      spec2 = [
        operation_id: :some_operation,
        request_body: {SomeSchema, [required: false]},
        responses: [ok: true]
      ]

      op2 = Operation.from_controller!(spec2)
      assert %Operation{requestBody: %RequestBody{required: false}} = op2

      # spec with a nested definition will respect the definition
      spec3 = [
        operation_id: :some_operation,
        request_body: [content: %{"application/json" => [schema: SomeSchema]}],
        responses: [ok: true]
      ]

      op3 = Operation.from_controller!(spec3)
      assert %Operation{requestBody: %RequestBody{required: false}} = op3
    end
  end

  describe "responses format" do
    test "giving a map is giving a schema for the application/json content type" do
      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: %{200 => {%{i_am_a_schema: true}, []}}
      ]

      op = Operation.from_controller!(spec)

      assert %Oaskit.Spec.Operation{
               responses: %{
                 200 => %Oaskit.Spec.Response{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: %{i_am_a_schema: true}
                     }
                   },
                   description: "no description"
                 }
               }
             } = op
    end

    test "using a reference for the response" do
      alias Oaskit.Spec.Reference

      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: %{200 => %Reference{"$ref": "#/responses/SomeResp"}}
      ]

      op = Operation.from_controller!(spec)

      assert %Oaskit.Spec.Operation{
               responses: %{
                 200 => %Oaskit.Spec.Reference{}
               }
             } = op
    end

    test "giving a tuple is giving a schema and other options" do
      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: %{200 => {%{i_am_a_schema: true}, description: "some descr"}}
      ]

      op = Operation.from_controller!(spec)

      assert %Oaskit.Spec.Operation{
               responses: %{
                 200 => %Oaskit.Spec.Response{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: %{i_am_a_schema: true}
                     }
                   },
                   description: "some descr"
                 }
               }
             } = op
    end

    test "description is taken from the schema only if not provided" do
      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: %{
          200 => {%{i_am_a_schema: true, description: "from schema"}, description: "from opts"},
          400 => {%{i_am_a_schema: true, description: "from schema"}, []}
        }
      ]

      op = Operation.from_controller!(spec)

      assert %Oaskit.Spec.Operation{
               responses: %{
                 200 => %Oaskit.Spec.Response{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: %{i_am_a_schema: true}
                     }
                   },
                   description: "from opts"
                 },
                 400 => %Oaskit.Spec.Response{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: %{i_am_a_schema: true}
                     }
                   },
                   description: "from schema"
                 }
               }
             } = op
    end

    test "spec with provided content" do
      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: %{
          200 => [description: "hello", content: %{"xxx/xxx" => [schema: %{i_am_a_schema: true}]}]
        }
      ]

      op = Operation.from_controller!(spec)

      assert %Oaskit.Spec.Operation{
               responses: %{
                 200 => %Oaskit.Spec.Response{
                   content: %{
                     "xxx/xxx" => %Oaskit.Spec.MediaType{
                       schema: %{i_am_a_schema: true}
                     }
                   },
                   description: "hello"
                 }
               }
             } = op
    end

    test "supports atom codes" do
      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: [ok: true, bad_request: true]
      ]

      op = Operation.from_controller!(spec)

      assert %Oaskit.Spec.Operation{
               responses: %{
                 200 => %Oaskit.Spec.Response{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: true
                     }
                   },
                   description: "no description"
                 },
                 400 => %Oaskit.Spec.Response{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: true
                     }
                   },
                   description: "no description"
                 }
               }
             } = op
    end

    test "invalid atom codes" do
      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: [SOME_UNKNOWN_STATUS: %{}]
      ]

      assert_raise ArgumentError, ~r/invalid status .+ :SOME_UNKNOWN_STATUS/, fn ->
        Operation.from_controller!(spec)
      end
    end

    test "unknown integer codes are accepted" do
      spec = [
        operation_id: :some_operation,
        request_body: SomeSchema,
        responses: %{123_456 => {%{}, []}}
      ]

      assert %Oaskit.Spec.Operation{
               responses: %{
                 123_456 => %Oaskit.Spec.Response{}
               }
             } = Operation.from_controller!(spec)
    end
  end

  describe "tags macro" do
    test "shared tags are applied when operation omits tags key" do
      # Shared tags should be applied even when `tags:` is not specified
      # in the operation spec
      spec = [
        operation_id: :some_operation,
        responses: [ok: true]
      ]

      op = Operation.from_controller!(spec, shared_tags: ["users", "v1"])

      assert %Operation{tags: ["users", "v1"]} = op
    end

    test "shared tags are merged with operation tags" do
      spec = [
        operation_id: :some_operation,
        tags: ["slow"],
        responses: [ok: true]
      ]

      op = Operation.from_controller!(spec, shared_tags: ["users", "v1"])

      assert %Operation{tags: tags} = op
      assert "slow" in tags
      assert "users" in tags
      assert "v1" in tags
    end

    test "operation tags take precedence over shared tags for duplicates" do
      spec = [
        operation_id: :some_operation,
        tags: ["users", "custom"],
        responses: [ok: true]
      ]

      op = Operation.from_controller!(spec, shared_tags: ["users", "v1"])

      assert %Operation{tags: tags} = op
      # Should contain unique tags only
      assert length(Enum.filter(tags, &(&1 == "users"))) == 1
    end

    test "empty shared_tags with no operation tags results in nil" do
      spec = [
        operation_id: :some_operation,
        responses: [ok: true]
      ]

      op = Operation.from_controller!(spec, shared_tags: [])

      # When no shared tags and no operation tags, tags should be nil
      assert %Operation{tags: nil} = op
    end

    test "explicit nil tags overrides shared tags" do
      spec = [
        operation_id: :some_operation,
        tags: nil,
        responses: [ok: true]
      ]

      op = Operation.from_controller!(spec, shared_tags: ["users", "v1"])

      # Explicitly passing tags: nil should override shared tags
      assert %Operation{tags: nil} = op
    end
  end
end
