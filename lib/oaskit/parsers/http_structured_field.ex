defmodule Oaskit.Parsers.HttpStructuredField do
  alias Oaskit.Parsers.HttpStructuredField.Parser

  @moduledoc """
  HTTP Structured Field parser implementation following RFC 8941.
  """

  def parse_sf_item(input, opts \\ []) do
    with {:ok, input} <- trim_not_empty(input),
         {:ok, item, ""} <- Parser.parse_sf_item(input) do
      {:ok, post_process_item(item, opts)}
    end
  end

  def parse_sf_list(input, opts \\ []) do
    with {:ok, input} <- trim_not_empty(input),
         {:ok, list, ""} <- Parser.parse_sf_list(input) do
      {:ok, post_process_list(list, opts)}
    end
  end

  def parse_sf_dictionary(input, opts \\ []) do
    with {:ok, input} <- trim_not_empty(input),
         {:ok, dict, ""} <- Parser.parse_sf_dictionary(input) do
      {:ok, post_process_dict(dict, opts)}
    end
  end

  defp trim_not_empty(input) do
    case String.trim(input) do
      "" -> Parser.error(:empty, input)
      rest -> {:ok, rest}
    end
  end

  def post_process_item(elem, opts) do
    maps? = true == opts[:maps]
    unwrap? = true == opts[:unwrap]
    post_process_item(elem, unwrap?, maps?)
  end

  defp post_process_item(elem, false, false) do
    elem
  end

  defp post_process_item({type, value, params}, unwrap?, maps?)
       when type in [:integer, :decimal, :string, :token, :byte_sequence, :boolean] do
    params = post_process_params(params, unwrap?, maps?)

    if unwrap? do
      {value, params}
    else
      {type, value, params}
    end
  end

  defp post_process_item({:inner_list, items, params}, unwrap?, maps?) do
    params = post_process_params(params, unwrap?, maps?)
    items = Enum.map(items, &post_process_item(&1, unwrap?, maps?))

    if unwrap? do
      {items, params}
    else
      {:inner_list, items, params}
    end
  end

  def post_process_list(list, opts) do
    maps? = true == opts[:maps]
    unwrap? = true == opts[:unwrap]
    post_process_list(list, unwrap?, maps?)
  end

  defp post_process_list(list, false, false) do
    list
  end

  defp post_process_list(list, unwrap?, maps?) do
    Enum.map(list, &post_process_item(&1, unwrap?, maps?))
  end

  def post_process_dict(dict, opts) do
    maps? = true == opts[:maps]
    unwrap? = true == opts[:unwrap]
    post_process_dict(dict, unwrap?, maps?)
  end

  defp post_process_dict(dict, false, false) do
    dict
  end

  defp post_process_dict(dict, unwrap?, maps?) do
    dict = Enum.map(dict, fn {key, value} -> {key, post_process_item(value, unwrap?, maps?)} end)

    if maps? do
      Map.new(dict)
    else
      dict
    end
  end

  defp post_process_params(params, unwrap?, maps?) do
    params =
      if unwrap? do
        unwrap_params(params)
      else
        params
      end

    params =
      if maps? do
        Map.new(params)
      else
        params
      end

    params
  end

  defp unwrap_params(params) do
    Enum.map(params, &unwrap_param/1)
  end

  defp unwrap_param({key, {_type, value}}) do
    {key, value}
  end
end
