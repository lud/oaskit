defmodule Oaskit.TestWeb.Helpers do
  @moduledoc false
  alias Oaskit.ErrorHandler.Default

  def dummy_responses do
    [ok: {%{_dummy_schema: true}, []}]
  end

  def dummy_responses_with_error do
    [ok: {%{_dummy_schema: true}, []}, default: Default.ErrorResponseSchema]
  end
end
