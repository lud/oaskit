defmodule Oaskit.TestWeb.Helpers do
  @moduledoc false

  def dummy_responses do
    [ok: {%{_dummy_schema: true}, []}]
  end
end
