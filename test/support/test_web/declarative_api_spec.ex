defmodule Oaskit.TestWeb.DeclarativeApiSpec do
  alias Oaskit.TestWeb.Schemas.AlchemistsPage
  alias Oaskit.TestWeb.Schemas.CreatePotionBody
  alias Oaskit.TestWeb.Schemas.Ingredient
  alias Oaskit.TestWeb.Schemas.Potion
  use Oaskit

  @moduledoc false

  @api_spec %{
    "openapi" => "3.1.1",
    "info" => %{
      "title" => "Alchemy Lab API",
      "version" => "1.0.0"
    },
    "paths" => %{
      "/potions" => %{"$ref" => "#/components/pathItems/CreatePotionPath"},
      "/{lab}/alchemists" => %{"$ref" => "#/components/pathItems/AlchemistsPath"}
    },
    "components" => %{
      "pathItems" => %{
        "CreatePotionPath" => %{
          "post" => %{
            "operationId" => "createPotion",
            "parameters" => [
              %{"$ref" => "#/components/parameters/DryRun"},
              %{"$ref" => "#/components/parameters/Source"}
            ],
            "requestBody" => %{"$ref" => "#/components/requestBodies/CreatePotionRequest"},
            "responses" => %{
              "200" => %{"$ref" => "#/components/responses/PotionCreated"}
            }
          }
        },
        "AlchemistsPath" => %{
          "parameters" => [
            %{"$ref" => "#/components/parameters/LaboratorySlug"},
            %{"$ref" => "#/components/parameters/Q"}
          ],
          "get" => %{
            "operationId" => "listAlchemists",
            "parameters" => [
              %{"$ref" => "#/components/parameters/PerPage"},
              %{"$ref" => "#/components/parameters/Page"}
            ],
            "responses" => %{
              "200" => %{"$ref" => "#/components/responses/AlchemistsPage"},
              "400" => %{"$ref" => "#/components/responses/BadRequest"}
            }
          },
          "post" => %{
            "operationId" => "searchAlchemists",
            "parameters" => [
              # This one overrides pathitems parameters
              %{
                "name" => "q",
                "in" => "query",
                "schema" => %{"type" => "string", "minLength" => 0}
              },
              # This one does not override as it is defined in query but
              # pathitem 'lab' parameter is defined in path.
              %{
                "name" => "lab",
                "in" => "query",
                "schema" => %{"type" => "string", "pattern" => "^someprefix:[a-z]+"}
              }
            ],
            "responses" => %{
              "200" => %{"$ref" => "#/components/responses/AlchemistsPage"}
            }
          }
        }
      },
      "parameters" => %{
        "DryRun" => %{
          "name" => "dry_run",
          "in" => "query",
          "schema" => %{"type" => "boolean"}
        },
        "Source" => %{
          "name" => "source",
          "in" => "query",
          "schema" => %{"type" => "string"}
        },
        "PerPage" => %{
          "name" => "per_page",
          "in" => "query",
          "schema" => %{"type" => "integer", "minimum" => 1}
        },
        "Page" => %{
          "name" => "page",
          "in" => "query",
          "schema" => %{"type" => "integer", "minimum" => 1}
        },
        "LaboratorySlug" => %{
          "name" => "lab",
          "in" => "path",
          "schema" => %{"$ref" => "#/components/parameters/LaboratorySlug"}
        },
        "Q" => %{
          "name" => "q",
          "in" => "query",
          "schema" => %{"type" => "string", "minLength" => 1}
        }
      },
      "requestBodies" => %{
        "CreatePotionRequest" => %{
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{"$ref" => "#/components/schemas/CreatePotionBody"}
            }
          }
        }
      },
      "responses" => %{
        "BadRequest" => %{
          "description" => "Bad request",
          "content" => %{
            "application/json" => %{
              "schema" => true
            }
          }
        },
        "PotionCreated" => %{
          "description" => "Potion created successfully",
          "content" => %{
            "application/json" => %{
              "schema" => %{"$ref" => "#/components/schemas/Potion"}
            }
          }
        },
        "AlchemistsPage" => %{
          "description" => "Page of Alchemists listing",
          "content" => %{
            "application/json" => %{
              "schema" => %{"$ref" => "#/components/schemas/AlchemistsPage"}
            }
          }
        }
      },
      "schemas" => %{
        "Ingredient" => Ingredient,
        "CreatePotionBody" => CreatePotionBody,
        "Potion" => Potion,
        "AlchemistsPage" => AlchemistsPage,
        "LaboratorySlug" => %{"type" => "string", "pattern" => "[a-zA-Z0-9_-]"}
      }
    }
  }

  def spec do
    @api_spec
  end
end
