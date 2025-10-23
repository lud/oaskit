defmodule Oaskit.SpecTest do
  alias JSV.Codec
  alias Oaskit.Spec.Components
  alias Oaskit.Spec.OpenAPI
  alias Oaskit.Spec.Paths
  alias Oaskit.SpecValidator
  alias Oaskit.TestWeb
  alias Oaskit.TestWeb.DeclarativeApiSpec
  use ExUnit.Case, async: true
  use JSV.Schema

  test "minimal test" do
    assert %OpenAPI{} =
             %{
               "openapi" => "hello",
               :info => %{"title" => "Some title", :version => "3.1"},
               :paths => %{}
             }
             |> Oaskit.normalize_spec!()
             |> cast_to_structs()
  end

  defp cast_to_structs(normal) do
    SpecValidator.validate!(normal)
  end

  test "petstore with references" do
    # the used document does not contain schemas as modules (it's a raw json)
    json =
      "test/support/data/petstore-refs.json"
      |> File.read!()
      |> Codec.decode!()

    assert %OpenAPI{} =
             Oaskit.normalize_spec!(json)
             |> cast_to_structs()
  end

  test "train travel API" do
    json =
      "test/support/data/train-travel-api.json"
      |> File.read!()
      |> Codec.decode!()

    assert %OpenAPI{} =
             Oaskit.normalize_spec!(json)
             |> cast_to_structs()
  end

  test "museum API" do
    json =
      "test/support/data/redocly-museum-api.json"
      |> File.read!()
      |> Codec.decode!()

    assert %OpenAPI{} =
             Oaskit.normalize_spec!(json)
             |> cast_to_structs()
  end

  test "raw spec from module" do
    # The DeclarativeApiSpec spec contains all special cases that we want to
    # test when normalizing/building from a raw document, notably using
    # references for various components.
    assert %Oaskit.Spec.OpenAPI{
             openapi: "3.1.1",
             info: %Oaskit.Spec.Info{
               title: "Alchemy Lab API",
               version: "1.0.0"
             },
             components: %Oaskit.Spec.Components{
               parameters: %{
                 "DryRun" => %Oaskit.Spec.Parameter{
                   in: :query,
                   name: "dry_run",
                   schema: %{"type" => "boolean"}
                 },
                 "Source" => %Oaskit.Spec.Parameter{
                   in: :query,
                   name: "source",
                   schema: %{"type" => "string"}
                 }
               },
               pathItems: %{
                 "CreatePotionPath" => %Oaskit.Spec.PathItem{
                   post: %Oaskit.Spec.Operation{
                     operationId: "createPotion",
                     parameters: [
                       %Oaskit.Spec.Reference{
                         "$ref": "#/components/parameters/DryRun"
                       },
                       %Oaskit.Spec.Reference{
                         "$ref": "#/components/parameters/Source"
                       }
                     ],
                     requestBody: %Oaskit.Spec.Reference{
                       "$ref": "#/components/requestBodies/CreatePotionRequest"
                     },
                     responses: %{
                       "200" => %Oaskit.Spec.Reference{
                         "$ref": "#/components/responses/PotionCreated"
                       }
                     }
                   }
                 }
               },
               requestBodies: %{
                 "CreatePotionRequest" => %Oaskit.Spec.RequestBody{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: %{"$ref" => "#/components/schemas/CreatePotionBody"}
                     }
                   },
                   required: true
                 }
               },
               responses: %{
                 "PotionCreated" => %Oaskit.Spec.Response{
                   content: %{
                     "application/json" => %Oaskit.Spec.MediaType{
                       schema: %{"$ref" => "#/components/schemas/Potion"}
                     }
                   },
                   description: "Potion created successfully"
                 }
               },
               schemas: %{
                 "CreatePotionBody" => %{
                   "jsv-cast" => ["Elixir.Oaskit.TestWeb.Schemas.CreatePotionBody", 0],
                   "properties" => %{
                     "ingredients" => %{
                       "items" => %{
                         "$ref" => "#/components/schemas/Ingredient"
                       },
                       "type" => "array"
                     },
                     "name" => %{"type" => "string"}
                   },
                   "required" => ["name", "ingredients"],
                   "type" => "object"
                 },
                 "Ingredient" => %{
                   "jsv-cast" => ["Elixir.Oaskit.TestWeb.Schemas.Ingredient", 0],
                   "properties" => %{
                     "name" => %{"type" => "string"},
                     "quantity" => %{"type" => "integer"},
                     "unit" => %{
                       "enum" => ["pinch", "dash", "scoop", "whiff", "nub"],
                       "type" => "string"
                     }
                   },
                   "required" => ["name", "quantity", "unit"],
                   "type" => "object"
                 },
                 "Potion" => %{
                   "jsv-cast" => ["Elixir.Oaskit.TestWeb.Schemas.Potion", 0],
                   "properties" => %{
                     "brewingTime" => %{"type" => "integer"},
                     "id" => %{"type" => "string"},
                     "ingredients" => %{
                       "items" => %{
                         "$ref" => "#/components/schemas/Ingredient"
                       },
                       "type" => "array"
                     },
                     "name" => %{"type" => "string"}
                   },
                   "required" => ["id", "name", "ingredients"],
                   "type" => "object"
                 }
               }
             },
             paths: %{
               "/potions" => %Oaskit.Spec.Reference{
                 "$ref": "#/components/pathItems/CreatePotionPath"
               }
             }
           } =
             DeclarativeApiSpec.spec()
             |> Oaskit.normalize_spec!()
             |> cast_to_structs()
  end

  describe "normalizing schemas" do
    # returns a Paths object
    #
    # If 2 schemas are given, then the 2 paths are "/p1" and "/p2", the
    # operations are "op1" and "op2" respectively.
    #
    # Schemas are used as both the request body and response body
    defp schemas_to_paths(schemas) do
      schemas
      |> Enum.with_index(1)
      |> Map.new(fn {schema, i} ->
        path = "/p#{i}"
        opid = "op#{i}"

        pathitem = %{
          "post" => %{
            "operationId" => opid,
            "responses" => %{
              "200" => %{
                "description" => "resp #{i}",
                "content" => %{"application/json" => %{"schema" => schema}}
              }
            },
            "requestBody" => %{
              "content" => %{"application/json" => %{"schema" => schema}}
            }
          }
        }

        {path, pathitem}
      end)
    end

    defp base(overrides) do
      Map.merge(
        %{"openapi" => "3.1.1", "info" => %{"title" => "spec_with_schemas", "version" => "0"}},
        overrides
      )
    end

    defschema MutualRecursiveA,
      b: Oaskit.SpecTest.MutualRecursiveB

    defschema MutualRecursiveB,
      a: MutualRecursiveA

    test "recursive schemas in components" do
      assert %Oaskit.Spec.OpenAPI{
               openapi: "3.1.1",
               info: %Oaskit.Spec.Info{
                 title: "spec_with_schemas",
                 version: "0"
               },
               components: %Components{
                 schemas: %{
                   # schema A defines a custom title, schema B does not and is
                   # registered with its module name
                   "MutualRecursiveA" => %{
                     "properties" => %{
                       "b" => %{
                         "$ref" => "#/components/schemas/MutualRecursiveB"
                       }
                     }
                   },
                   "MutualRecursiveB" => %{
                     "properties" => %{
                       "a" => %{"$ref" => "#/components/schemas/MutualRecursiveA"}
                     }
                   }
                 }
               },
               paths: %{
                 "/p1" => %Oaskit.Spec.PathItem{
                   post: %Oaskit.Spec.Operation{
                     operationId: "op1",
                     requestBody: %Oaskit.Spec.RequestBody{
                       content: %{
                         "application/json" => %Oaskit.Spec.MediaType{
                           schema: %{"$ref" => "#/components/schemas/MutualRecursiveA"}
                         }
                       }
                     },
                     responses: _
                   }
                 },
                 "/p2" => %Oaskit.Spec.PathItem{
                   post: %Oaskit.Spec.Operation{
                     operationId: "op2",
                     requestBody: %Oaskit.Spec.RequestBody{
                       content: %{
                         "application/json" => %Oaskit.Spec.MediaType{
                           schema: %{
                             "$ref" => "#/components/schemas/MutualRecursiveB"
                           }
                         }
                       }
                     },
                     responses: _
                   }
                 }
               }
             } =
               %{"paths" => schemas_to_paths([MutualRecursiveA, MutualRecursiveB])}
               |> base()
               |> Oaskit.normalize_spec!()
               |> cast_to_structs()
    end

    defschema Pet,
      name: string(),
      species: string()

    defschema Occupation,
      title: string()

    test "preexisting schemas in components" do
      # Base spec has a schema in the components, and an operation using another
      # schema with a title. Schema in components should remain there while the
      # other schema should be moved to components
      spec =
        %{
          "components" => %{
            "schemas" => %{
              "Person" => %{
                "title" => "Person",
                "type" => "object",
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "age" => %{"type" => "integer"},
                  # Raw maps can contain module schemas
                  "occupation" => Occupation
                },
                "required" => ["name"]
              }
            }
          },
          "paths" => schemas_to_paths([Pet])
        }
        |> base()
        |> Oaskit.normalize_spec!()
        |> cast_to_structs()

      # the spec should have both the Person and Pet schemas
      assert %{
               components: %{
                 schemas: %{
                   "Person" => %{"title" => "Person"},
                   "Pet" => %{"title" => "Pet"},
                   "Occupation" => %{"title" => "Occupation"}
                 }
               }
             } = spec
    end

    defschema IceCube, %{
      # Here the title is set to the predefined refname of the DrinkSchema. It
      # should not override the DrinkSchema, and will be incremented
      title: "SomeNameThatShouldNotChange",
      type: "object",
      properties: %{shape: %{enum: ["cube", "not actually a cube"]}},
      required: [:shape]
    }

    defschema DrinkSchema, %{
      title: "Drink",
      type: "object",
      properties: %{
        name: %{type: "string"},
        alcohol_degree: %{type: "integer"},
        ice: IceCube
      },
      required: [:name, :alcohol_degree]
    }

    test "preexisting schemas in components with a module" do
      # In this case the components contain a module name. This should not
      # happen when reading specs from a JSON file but it can be defined at
      # the spec module level for some reason (if the user generates dynamic
      # references on compilation instead of using module names for instance).

      spec =
        %{
          "components" => %{
            "schemas" => %{
              # A module schema with a custom refname
              "SomeNameThatShouldNotChange" => DrinkSchema,
              # An atom schema that should not be reused if another schema
              # somewhere is also `false`.
              "SomethingWeDoNotWant" => false,
              "OtherStufNotEvenASchema" => "no problem"
            }
          },
          # Here we use false as an atom schema, should not be replaced by a
          # ref.
          "paths" =>
            schemas_to_paths([
              Pet,
              %{type: :object, properties: %{pet: Pet}, additionalProperties: false}
            ])
        }
        |> base()
        |> Oaskit.normalize_spec!()
        |> cast_to_structs()

      # the spec should have both the Person and Pet schemas
      assert %{
               components: %{
                 schemas: %{
                   "SomethingWeDoNotWant" => false,
                   "SomeNameThatShouldNotChange" => %{"title" => "Drink"},
                   # Module subschema was successfully added with an incremented
                   # refname.
                   "SomeNameThatShouldNotChange_1" => %{"title" => "SomeNameThatShouldNotChange"},
                   "Pet" => %{"title" => "Pet"},
                   "OtherStufNotEvenASchema" => "no problem"
                 }
               }
             } = spec
    end

    test "nested schemas with the same title" do
      # This is a special case that actually happened when copy-pasting stuff.

      defmodule Child do
        require(JSV).defschema(%{
          type: :object,
          who: "child",
          title: "SameTitle",
          properties: %{foo: true}
        })
      end

      defmodule Parent do
        require(JSV).defschema(%{
          type: :object,
          who: "parent",
          title: "SameTitle",
          properties: %{child: Child}
        })
      end

      spec =
        %{
          "paths" => schemas_to_paths([Parent])
        }
        |> base()
        |> Oaskit.normalize_spec!()
        |> cast_to_structs()

      # The parent will be seen first so it should take the title
      assert %{
               "SameTitle" => %{"who" => "parent"},
               "SameTitle_1" => %{"who" => "child"}
             } = spec.components.schemas
    end
  end

  describe "phoenix routes" do
    test "extracting operations from phoenix routes" do
      # * Paths from the controllers that use the `operation` macro are present in
      #   the list.
      # * Paths using `use_operation` are not extracted, so the paths for the
      #   declarative test api spec are not there.

      assert [
               # Paths API Spec
               "/generated/body/boolean-schema-false",
               "/generated/body/form",
               "/generated/body/inline-single",
               "/generated/body/manual-form-handle",
               "/generated/body/manual-form-show",
               "/generated/body/module-single",
               "/generated/body/module-single-no-required",
               "/generated/body/wildcard",
               "/generated/meta/after-metas",
               "/generated/meta/before-metas",
               "/generated/meta/overrides-param",
               "/generated/method/p",
               "/generated/no-html-errors",
               "/generated/no-params",
               "/generated/params/{slug}/array-ref",
               "/generated/params/{slug}/arrays",
               "/generated/params/{slug}/boolean-schema-false",
               "/generated/params/{slug}/bracket-types",
               "/generated/params/{slug}/generic",
               "/generated/params/{slug}/s/{shape}",
               "/generated/params/{slug}/s/{shape}/t/{theme}",
               "/generated/params/{slug}/s/{shape}/t/{theme}/c/{color}",
               "/generated/params/{slug}/t/{theme}",
               "/generated/params/{slug}/t/{theme}/c/{color}",
               "/generated/resp/fortune-200-bad-content-type",
               "/generated/resp/fortune-200-invalid",
               "/generated/resp/fortune-200-no-content-def",
               "/generated/resp/fortune-200-req-body",
               "/generated/resp/fortune-200-valid",
               "/generated/resp/fortune-200-valid-from-ref",
               "/generated/resp/fortune-500-bad-default-resp",
               "/generated/resp/fortune-500-default-resp",

               # Security API Spec
               "/security/empty-security",
               "/security/multi-choice-security",
               "/security/multi-scheme-security",
               "/security/no-scopes",
               "/security/no-security",
               "/security/with-scopes"
             ] =
               %{
                 openapi: "3.1.1",
                 info: %{"title" => "Oaskit Test API", :version => "0.0.0"},
                 paths: Paths.from_router(TestWeb.Router)
               }
               |> Oaskit.normalize_spec!()
               |> cast_to_structs()
               |> Map.fetch!(:paths)
               |> Map.keys()
               |> Enum.sort()
    end

    test "removing prefix from paths" do
      paths =
        %{
          openapi: "3.1.1",
          info: %{"title" => "Oaskit Test API", :version => "0.0.0"},
          paths: Paths.from_router(TestWeb.Router, unprefix: "/generated")
        }
        |> Oaskit.normalize_spec!()
        |> cast_to_structs()
        |> Map.fetch!(:paths)
        |> Map.keys()

      assert "/body/boolean-schema-false" in paths
      assert "/body/form" in paths
      assert "/body/inline-single" in paths
    end
  end

  describe "server from phoenix" do
    test "extracting server info from phoenix config" do
      assert %OpenAPI{
               servers: [
                 %Oaskit.Spec.Server{url: "http://localhost:5001/"}
               ]
             } =
               %{
                 :openapi => "3.1.1",
                 :info => %{"title" => "Oaskit Test API", :version => "0.0.0"},
                 servers: [
                   Oaskit.Spec.Server.from_config(:oaskit, Oaskit.TestWeb.Endpoint)
                 ],
                 paths: %{}
               }
               |> Oaskit.normalize_spec!()
               |> cast_to_structs()
    end
  end

  describe "meta macros" do
    test "parameter and tags macro merge into the operations" do
      spec =
        %{
          :openapi => "3.1.1",
          :info => %{"title" => "Oaskit Test API", :version => "0.0.0"},
          :paths => Paths.from_router(TestWeb.Router)
        }
        |> Oaskit.normalize_spec!()
        |> cast_to_structs()

      # operation before shared items has no tags and no parameters
      assert %{operationId: "meta_before", parameters: nil, tags: nil} =
               spec.paths["/generated/meta/before-metas"].get

      # operation after has its own tags and parameters, and the shared ones
      assert %{
               operationId: "meta_after",
               parameters: [
                 %{in: :query, name: "self1"},
                 %{in: :query, name: "self2"},
                 %{in: :query, name: "shared1"},
                 %{in: :query, name: "shared2", schema: %{"pattern" => "[0-9]+"}}
               ],
               tags: ["zzz", "aaa", "shared1", "shared2"]
             } =
               spec.paths["/generated/meta/after-metas"].get

      # operation overriding a param in query, and defining an homonym but in path
      assert %{
               operationId: "meta_override",
               parameters: [
                 %{in: :query, name: "shared2", schema: %{"overriden" => true}},
                 %{in: :path, name: "shared1"},
                 %{in: :query, name: "shared1"}
               ],
               tags: ["shared1", "zzz", "shared2"]
             } =
               spec.paths["/generated/meta/overrides-param"].get
    end
  end
end
