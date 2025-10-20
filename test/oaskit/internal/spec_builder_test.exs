defmodule Oaskit.Internal.SpecBuilderTest do
  alias Oaskit.Internal.Normalizer
  alias Oaskit.Internal.SpecBuilder
  alias Oaskit.Spec.MediaType
  alias Oaskit.Spec.OpenAPI
  alias Oaskit.Spec.Operation
  alias Oaskit.Spec.Parameter
  alias Oaskit.Spec.Paths
  alias Oaskit.Spec.RequestBody
  alias Oaskit.TestWeb.DeclarativeApiSpec
  alias Oaskit.TestWeb.PathsApiSpec
  use ExUnit.Case, async: true

  defmodule BodySchema do
    require(JSV).defschema(%{
      type: :object,
      properties: %{
        some_required: %{type: :integer},
        some_optional: %{type: :string}
      },
      required: [:some_required]
    })
  end

  @normal_sample_spec Normalizer.normalize!(%OpenAPI{
                        openapi: "some version",
                        info: %{title: "some title", version: "some vsn"},
                        paths: %{
                          "/json-endpoint": %{
                            get: %Operation{
                              operationId: "json_1",
                              parameters: [
                                %Parameter{name: :param_p1, in: :path, schema: %{type: :integer}},
                                %Parameter{
                                  name: :param_q1_orderby,
                                  in: :query,
                                  schema: %{type: :array, items: %{type: :string}}
                                }
                              ],
                              requestBody: %RequestBody{
                                content: %{
                                  "application/json" => %MediaType{
                                    schema: BodySchema
                                  }
                                }
                              },
                              responses: %{ok: %{description: "some response"}}
                            }
                          }
                        }
                      })

  test "build validations for request bodies" do
    assert {built, _} =
             SpecBuilder.build_operations(@normal_sample_spec, %{
               responses: false,
               jsv_opts: Oaskit.default_jsv_opts()
             })

    assert is_map_key(built, "json_1")

    assert %{
             "json_1" => %{
               security: _,
               validation: [
                 {:parameters,
                  %{
                    path: [
                      %{
                        in: :path,
                        key: :param_p1,
                        required: true,
                        schema_key:
                          {:precast, precast,
                           {:pointer, :root,
                            ["paths", "/json-endpoint", "get", "parameters", 0, "schema"]}},
                        bin_key: "param_p1"
                      }
                    ],
                    query: [
                      %{
                        in: :query,
                        key: :param_q1_orderby,
                        required: false,
                        schema_key:
                          {:pointer, :root,
                           ["paths", "/json-endpoint", "get", "parameters", 1, "schema"]},
                        bin_key: "param_q1_orderby"
                      }
                    ]
                  }},
                 {:body, false,
                  [
                    {{"application", "json"},
                     {:pointer, :root,
                      [
                        "paths",
                        "/json-endpoint",
                        "get",
                        "requestBody",
                        "content",
                        "application/json",
                        "schema"
                      ]}}
                  ]}
               ]
             }
           } = built

    assert [precast_fun | []] = precast
    %{module: JSV.Cast, name: :string_to_integer, arity: 1} = Map.new(Function.info(precast_fun))
  end

  test "duplicate operation ids" do
    defmodule DupAController do
      alias Oaskit.TestWeb.Helpers
      use Oaskit.Controller

      operation :a,
        operation_id: "same-same",
        responses: Helpers.dummy_responses()
    end

    defmodule DupBController do
      alias Oaskit.TestWeb.Helpers
      use Oaskit.Controller

      operation :b,
        operation_id: "same-same",
        responses: Helpers.dummy_responses()
    end

    defmodule SomeRouterWithDuplicates do
      use Phoenix.Router

      get "/a", DupAController, :a
      get "/b", DupBController, :b
    end

    # No error on normalization
    normal =
      Oaskit.normalize_spec!(%{
        :openapi => "3.1.1",
        :info => %{"title" => "Oaskit Test API", :version => "0.0.0"},
        :paths => Paths.from_router(SomeRouterWithDuplicates)
      })

    assert_raise ArgumentError, ~r{duplicate operation id "same-same"}, fn ->
      SpecBuilder.build_operations(normal, %{
        responses: false,
        jsv_opts: Oaskit.default_jsv_opts()
      })
    end
  end

  describe "using generated api spec" do
    test "params and bodies" do
      # just check that it can be built for now. The tests of the controllers
      # ensures that the validation is effective
      assert {built, _} = Oaskit.build_spec!(PathsApiSpec, cache: false)

      # We just want to make sure that by default there is no useless building
      # of the responses schemas
      Enum.each(built, fn {_opid, %{validation: validations}} ->
        refute Keyword.has_key?(validations, :responses)
      end)
    end

    test "with responses" do
      assert {built, _} = Oaskit.build_spec!(PathsApiSpec, cache: false, responses: true)

      # We just want to make sure that by default there is no useless building
      # of the responses schemas
      Enum.each(built, fn {_opid, %{validation: validations}} ->
        assert Keyword.has_key?(validations, :responses)
        validations[:responses]
      end)
    end
  end

  describe "using spec from maps" do
    test "basic build" do
      # The DeclarativeApiSpec spec contains all special cases that we want to
      # test when normalizing/building from a raw document, notably using
      # references for various components.

      assert {built, _} = Oaskit.build_spec!(DeclarativeApiSpec, cache: false)

      assert %{
               "createPotion" => %{
                 security: _,
                 validation: [
                   {:parameters,
                    %{
                      path: [],
                      query: [
                        %{
                          in: :query,
                          key: :dry_run,
                          required: false,
                          schema_key:
                            {:precast, precast,
                             {:pointer, :root, ["components", "parameters", "DryRun", "schema"]}},
                          bin_key: "dry_run"
                        },
                        %{
                          in: :query,
                          key: :source,
                          required: false,
                          schema_key:
                            {:pointer, :root, ["components", "parameters", "Source", "schema"]},
                          bin_key: "source"
                        }
                      ]
                    }},
                   {:body, true,
                    [
                      {{"application", "json"},
                       {:pointer, :root,
                        [
                          "components",
                          "requestBodies",
                          "CreatePotionRequest",
                          "content",
                          "application/json",
                          "schema"
                        ]}}
                    ]}
                 ]
               }
             } =
               built

      assert [precast_fun | []] = precast

      assert %{module: JSV.Cast, name: :string_to_boolean, arity: 1} =
               Map.new(Function.info(precast_fun))
    end

    test "with responses" do
      assert {built, _} = Oaskit.build_spec!(DeclarativeApiSpec, cache: false, responses: true)

      Enum.each(built, fn {_opid, %{security: _, validation: validations}} ->
        assert Keyword.has_key?(validations, :responses)
      end)

      # if the responses are properly built we should be able to
    end

    test "building petstore where most things are given as references" do
      # This should pass. We are not implementing a controller to test it
      # thoroughly though.
      "test/support/data/petstore-refs.json"
      |> File.read!()
      |> JSV.Codec.decode!()
      |> Normalizer.normalize!()
      |> SpecBuilder.build_operations(%{
        responses: false,
        jsv_opts: Oaskit.default_jsv_opts()
      })
    end
  end
end
