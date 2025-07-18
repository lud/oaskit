defmodule Oaskit.TestWeb.MetaController do
  use Oaskit.TestWeb, :controller

  @moduledoc false

  operation :before_metas,
    operation_id: "meta_before",
    responses: dummy_responses()

  @spec before_metas(term, term) :: no_return()
  def before_metas(_conn, _) do
    raise "should not be called"
  end

  tags ["shared1", "zzz"]
  parameter :shared1, in: :query

  tags ["shared2", "zzz"]
  parameter :shared2, in: :query, schema: %{pattern: "[0-9]+"}

  operation :after_metas,
    operation_id: "meta_after",
    tags: ["zzz", "aaa"],
    parameters: [
      self1: [in: :query],
      self2: [in: :query]
    ],
    responses: dummy_responses()

  @spec after_metas(term, term) :: no_return()
  def after_metas(_conn, _) do
    raise "should not be called"
  end

  operation :overrides_param,
    operation_id: "meta_override",
    tags: [],
    parameters: [
      shared2: [in: :query, schema: %{"overriden" => true}],
      # not an override as we are defining this one in path
      shared1: [in: :path]
    ],
    responses: dummy_responses()

  @spec overrides_param(term, term) :: no_return()
  def overrides_param(_conn, _) do
    raise "should not be called"
  end
end
