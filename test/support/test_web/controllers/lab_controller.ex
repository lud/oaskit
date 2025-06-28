defmodule OpenApify.TestWeb.LabController do
  alias OpenApify.TestWeb.Responder
  use OpenApify.TestWeb, :controller

  use_operation :create_potion, "createPotion"

  def create_potion(conn, params) do
    Responder.reply(conn, params)
  end

  use_operation :list_alchemists, "listAlchemists"

  def list_alchemists(conn, params) do
    Responder.reply(conn, params)
  end

  use_operation :search_alchemists, "searchAlchemists"

  def search_alchemists(conn, params) do
    Responder.reply(conn, params)
  end
end
