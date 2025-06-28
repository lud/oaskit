defmodule OpenApify.SpecTest do
  alias JSV.Codec
  alias OpenApify.Internal.SpecValidator
  alias OpenApify.Spec.Components
  alias OpenApify.Spec.OpenAPI
  alias OpenApify.Spec.Paths
  alias OpenApify.TestWeb
  alias OpenApify.TestWeb.DeclarativeApiSpec
  use ExUnit.Case, async: true

  test "minimal test" do
    assert %OpenAPI{} =
             %{
               "openapi" => "hello",
               :info => %{"title" => "Some title", :version => "3.1"},
               :paths => %{}
             }
             |> OpenApify.normalize_spec!()
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
             OpenApify.normalize_spec!(json)
             |> cast_to_structs()
  end

  test "train travel API" do
    json =
      "test/support/data/train-travel-api.json"
      |> File.read!()
      |> Codec.decode!()

    assert %OpenAPI{} =
             OpenApify.normalize_spec!(json)
             |> cast_to_structs()
  end

  test "museum API" do
    json =
      "test/support/data/redocly-museum-api.json"
      |> File.read!()
      |> Codec.decode!()

    assert %OpenAPI{} =
             OpenApify.normalize_spec!(json)
             |> cast_to_structs()
  end

  test "raw spec from module" do
    # The DeclarativeApiSpec spec contains all special cases that we want to
    # test when normalizing/building from a raw document, notably using
    # references for various components.
    assert %OpenApify.Spec.OpenAPI{
             openapi: "3.1.0",
             info: %OpenApify.Spec.Info{
               title: "Alchemy Lab API",
               version: "1.0.0"
             },
             components: %OpenApify.Spec.Components{
               parameters: %{
                 "DryRun" => %OpenApify.Spec.Parameter{
                   in: :query,
                   name: "dry_run",
                   schema: %{"type" => "boolean"}
                 },
                 "Source" => %OpenApify.Spec.Parameter{
                   in: :query,
                   name: "source",
                   schema: %{"type" => "string"}
                 }
               },
               pathItems: %{
                 "CreatePotionPath" => %OpenApify.Spec.PathItem{
                   post: %OpenApify.Spec.Operation{
                     operationId: "createPotion",
                     parameters: [
                       %OpenApify.Spec.Reference{
                         "$ref": "#/components/parameters/DryRun"
                       },
                       %OpenApify.Spec.Reference{
                         "$ref": "#/components/parameters/Source"
                       }
                     ],
                     requestBody: %OpenApify.Spec.Reference{
                       "$ref": "#/components/requestBodies/CreatePotionRequest"
                     },
                     responses: %{
                       "200" => %OpenApify.Spec.Reference{
                         "$ref": "#/components/responses/PotionCreated"
                       }
                     }
                   }
                 }
               },
               requestBodies: %{
                 "CreatePotionRequest" => %OpenApify.Spec.RequestBody{
                   content: %{
                     "application/json" => %OpenApify.Spec.MediaType{
                       schema: %{"$ref" => "#/components/schemas/CreatePotionBody"}
                     }
                   },
                   required: true
                 }
               },
               responses: %{
                 "PotionCreated" => %OpenApify.Spec.Response{
                   content: %{
                     "application/json" => %OpenApify.Spec.MediaType{
                       schema: %{"$ref" => "#/components/schemas/Potion"}
                     }
                   },
                   description: "Potion created successfully"
                 }
               },
               schemas: %{
                 "CreatePotionBody" => %{
                   "jsv-cast" => ["Elixir.OpenApify.TestWeb.Schemas.CreatePotionBody", 0],
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
                   "jsv-cast" => ["Elixir.OpenApify.TestWeb.Schemas.Ingredient", 0],
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
                   "jsv-cast" => ["Elixir.OpenApify.TestWeb.Schemas.Potion", 0],
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
               "/potions" => %OpenApify.Spec.Reference{
                 "$ref": "#/components/pathItems/CreatePotionPath"
               }
             }
           } =
             DeclarativeApiSpec.spec()
             |> OpenApify.normalize_spec!()
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

    defmodule Standalone do
      alias OpenApify.SpecTest.MutualRecursiveB

      def schema do
        %{
          title: "Standalone",
          type: :integer
        }
      end
    end

    defmodule MutualRecursiveA do
      alias OpenApify.SpecTest.MutualRecursiveB

      require(JSV).defschema(%{
        type: :object,
        title: "RecA",
        properties: %{
          b: MutualRecursiveB
        }
      })
    end

    defmodule MutualRecursiveB do
      require(JSV).defschema(%{
        type: :object,
        properties: %{
          a: MutualRecursiveA
        }
      })
    end

    test "recursive schemas in components" do
      assert %OpenApify.Spec.OpenAPI{
               openapi: "3.1.1",
               info: %OpenApify.Spec.Info{
                 title: "spec_with_schemas",
                 version: "0"
               },
               components: %Components{
                 schemas: %{
                   # schema A defines a custom title, schema B does not and is
                   # registered with its module name
                   "RecA" => %{
                     "properties" => %{
                       "b" => %{
                         "$ref" => "#/components/schemas/OpenApify.SpecTest.MutualRecursiveB"
                       }
                     }
                   },
                   "OpenApify.SpecTest.MutualRecursiveB" => %{
                     "properties" => %{"a" => %{"$ref" => "#/components/schemas/RecA"}}
                   }
                 }
               },
               paths: %{
                 "/p1" => %OpenApify.Spec.PathItem{
                   post: %OpenApify.Spec.Operation{
                     operationId: "op1",
                     requestBody: %OpenApify.Spec.RequestBody{
                       content: %{
                         "application/json" => %OpenApify.Spec.MediaType{
                           schema: %{"$ref" => "#/components/schemas/RecA"}
                         }
                       }
                     },
                     responses: _
                   }
                 },
                 "/p2" => %OpenApify.Spec.PathItem{
                   post: %OpenApify.Spec.Operation{
                     operationId: "op2",
                     requestBody: %OpenApify.Spec.RequestBody{
                       content: %{
                         "application/json" => %OpenApify.Spec.MediaType{
                           schema: %{
                             "$ref" => "#/components/schemas/OpenApify.SpecTest.MutualRecursiveB"
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
               |> OpenApify.normalize_spec!()
               |> cast_to_structs()
    end

    defmodule PetSchema do
      import JSV

      defschema(%{
        title: "Pet",
        type: "object",
        properties: %{
          name: %{type: "string"},
          species: %{type: "string"}
        },
        required: [:name, :species]
      })
    end

    defmodule OccupationSchema do
      import JSV

      defschema(%{
        title: "Occupation",
        type: "object",
        properties: %{
          title: %{type: :string}
        },
        required: [:title]
      })
    end

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
                  "occupation" => OccupationSchema
                },
                "required" => ["name"]
              }
            }
          },
          "paths" => schemas_to_paths([PetSchema])
        }
        |> base()
        |> OpenApify.normalize_spec!()
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

    defmodule IceCubeSchema do
      import JSV

      defschema(%{
        # Here the title is set to the predefined refname of the DrinkSchema. It
        # should not override the DrinkSchema, and will be incremented
        title: "SomeNameThatShouldNotChange",
        type: "object",
        properties: %{
          shape: %{enum: ["cube", "not actually a cube"]}
        },
        required: [:shape]
      })
    end

    defmodule DrinkSchema do
      import JSV

      defschema(%{
        title: "Drink",
        type: "object",
        properties: %{
          name: %{type: "string"},
          alcohol_degree: %{type: "integer"},
          ice: IceCubeSchema
        },
        required: [:name, :alcohol_degree]
      })
    end

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
              PetSchema,
              %{type: :object, properties: %{pet: PetSchema}, additionalProperties: false}
            ])
        }
        |> base()
        |> OpenApify.normalize_spec!()
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
  end

  describe "phoenix routes" do
    test "extracting operations from phoenix routes" do
      assert [
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
               "/generated/params/{slug}/arrays",
               "/generated/params/{slug}/boolean-schema-false",
               "/generated/params/{slug}/generic",
               "/generated/params/{slug}/s/{shape}",
               "/generated/params/{slug}/s/{shape}/t/{theme}",
               "/generated/params/{slug}/s/{shape}/t/{theme}/c/{color}",
               "/generated/params/{slug}/t/{theme}",
               "/generated/params/{slug}/t/{theme}/c/{color}",
               "/generated/resp/fortune-200-bad-content-type",
               "/generated/resp/fortune-200-invalid",
               "/generated/resp/fortune-200-no-content-def",
               "/generated/resp/fortune-200-valid",
               "/generated/resp/fortune-500-bad-default-resp",
               "/generated/resp/fortune-500-default-resp"
             ] =
               %{
                 openapi: "3.1.1",
                 info: %{"title" => "OpenApify Test API", :version => "0.0.0"},
                 paths: Paths.from_router(TestWeb.Router)
               }
               |> OpenApify.normalize_spec!()
               |> cast_to_structs()
               |> Map.fetch!(:paths)
               |> Map.keys()
               |> Enum.sort()
    end
  end

  describe "server from phoenix" do
    test "extracting server info from phoenix config" do
      assert %OpenAPI{
               servers: [
                 %OpenApify.Spec.Server{url: "http://localhost:5001/"}
               ]
             } =
               %{
                 :openapi => "3.1.1",
                 :info => %{"title" => "OpenApify Test API", :version => "0.0.0"},
                 servers: [
                   OpenApify.Spec.Server.from_config(:open_apify, OpenApify.TestWeb.Endpoint)
                 ],
                 paths: %{}
               }
               |> OpenApify.normalize_spec!()
               |> cast_to_structs()
    end
  end

  describe "meta macros" do
    test "parameter and tags macro merge into the operations" do
      spec =
        %{
          :openapi => "3.1.1",
          :info => %{"title" => "OpenApify Test API", :version => "0.0.0"},
          :paths => Paths.from_router(TestWeb.Router)
        }
        |> OpenApify.normalize_spec!()
        |> cast_to_structs()

      # operation before shared items has no tags and no parameters
      assert %{operationId: "meta_before", parameters: [], tags: []} =
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
