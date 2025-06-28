defmodule Oaskit.ErrorHandler.Default do
  alias JSV.Codec
  alias Oaskit.Errors.InvalidBodyError
  alias Oaskit.Errors.InvalidParameterError
  alias Oaskit.Errors.MissingParameterError
  alias Oaskit.Errors.UnsupportedMediaTypeError
  alias Plug.Conn
  alias Plug.Conn.Status

  @status_invalid_body :unprocessable_entity
  @status_unsupported_media_type :unsupported_media_type
  @status_parameters_errors :bad_request

  @moduledoc """
  The default error handler for validation errors.

  Returns various HTTP error codes depending on the validation failure:

  * `#{Status.code(@status_invalid_body)}`
    _#{Status.reason_phrase(Status.code(@status_invalid_body))}_ - When JSON
    schema errors when validating request bodies.
  * `#{Status.code(@status_unsupported_media_type)}`
    _#{Status.reason_phrase(Status.code(@status_unsupported_media_type))}_ -
    When matching the request content-type to the accepted content-types.
  * `#{Status.code(@status_parameters_errors)}`
    _#{Status.reason_phrase(Status.code(@status_parameters_errors))}_ - When
    validating query and path parameters.

  ## Error formatting

  For request specifically accepting HTML (`"html"` is found in the Accept
  header), this handler will present errors in an HTML document with basic
  styles.

  In any other case, a JSON representation of errors is returned with the
  `"application/json"` content type.

  Disable HTML entirely with the `html_errors: false` option when using the
  `#{inspect(Oaskit.Plugs.ValidateRequest)}` plug.
  """

  @behaviour Oaskit.ErrorHandler

  # sobelow_skip ["XSS.ContentType", "XSS.SendResp"]
  def handle_error(conn, reason, opts) do
    operation_id = conn.private.oaskit.operation_id

    # we will render HTML for any content
    format = response_formatter(conn, opts)
    status = response_status(reason)

    body = format_reason(format, reason, status, operation_id)

    conn
    |> Conn.put_resp_content_type(resp_content_type(format))
    |> Conn.send_resp(status, body)
    |> Conn.halt()
  end

  defp response_formatter(conn, opts) do
    with true <- Keyword.get(opts, :html_errors),
         [accept | _] <- Plug.Conn.get_req_header(conn, "accept"),
         true <- accept =~ "html" do
      :html
    else
      _ -> {:json, json_opts(opts)}
    end
  end

  defp response_status(reason) do
    case reason do
      # 422
      %InvalidBodyError{} -> :unprocessable_entity
      # 415
      %UnsupportedMediaTypeError{} -> :unsupported_media_type
      # 400
      {:parameters_errors, [_ | _]} -> :bad_request
    end
  end

  defp json_opts(opts) do
    case Keyword.fetch(opts, :pretty_errors) do
      {:ok, true} -> [pretty: true]
      _ -> []
    end
  end

  defp resp_content_type(format) do
    case format do
      {:json, _} -> "application/json"
      :html -> "text/html"
    end
  end

  defp format_reason({:json, json_opts}, reason, status, operation_id) do
    payload = %{error: reason_to_json(reason, status, operation_id)}
    json_encode(payload, json_opts)
  end

  defp format_reason(:html, reason, status, operation_id) do
    errors = format_html_errors(reason)
    code = Conn.Status.code(status)
    message = status_to_message(status)

    """
    <!doctype html>
    <style>#{css()}</style>
    <title>#{message}</title>

    <h1><span class="status">HTTP ERROR #{code}</span> #{message} </h1>

    <p>Invalid request for operation <code>#{operation_id}</code>.</p>

    <ol>
    #{errors}
    </ol>
    """
  end

  defp base_json_error(status, operation_id, overrides) do
    Map.merge(
      %{
        message: status_to_message(status),
        kind: status,
        operation_id: operation_id
      },
      overrides
    )
  end

  defp reason_to_json(%InvalidBodyError{} = e, status, operation_id) do
    base_json_error(status, operation_id, %{
      "in" => "body",
      "validation_error" => JSV.normalize_error(e.validation_error)
    })
  end

  defp reason_to_json(%UnsupportedMediaTypeError{} = e, status, operation_id) do
    base_json_error(status, operation_id, %{
      "in" => "body",
      "media_type" => e.media_type
    })
  end

  defp reason_to_json({:parameters_errors, list}, status, operation_id) do
    base_json_error(status, operation_id, %{
      "in" => "parameters",
      "parameters_errors" => list |> sort_errors() |> Enum.map(&parameter_error_to_json/1)
    })
  end

  defp parameter_error_to_json(%InvalidParameterError{} = e) do
    %{in: loc, name: name, validation_error: verr} = e

    %{
      "kind" => "invalid_parameter",
      "parameter" => name,
      "in" => loc,
      "validation_error" => JSV.normalize_error(verr),
      "message" => "invalid parameter #{name} in #{loc}"
    }
  end

  defp parameter_error_to_json(%MissingParameterError{} = e) do
    %{in: loc, name: name} = e

    %{
      "kind" => "missing_parameter",
      "parameter" => name,
      "in" => loc,
      "message" => Exception.message(e)
    }
  end

  defp status_to_message(status) when is_atom(status) do
    status
    |> Status.code()
    |> Status.reason_phrase()
  end

  defp format_html_errors(reason) do
    reason
    |> sort_errors()
    |> Enum.map_intersperse("\n\n\n", &reason_to_html/1)
  end

  # sort_errors also converts the reason to a list if not already a list, this
  # is useful to render html blocks. For json rendering it is only called for
  # parameters.

  defp sort_errors(%InvalidBodyError{} = e) do
    [e]
  end

  defp sort_errors(%UnsupportedMediaTypeError{} = e) do
    [e]
  end

  defp sort_errors({:parameters_errors, list}) do
    sort_errors(list)
  end

  defp sort_errors(errors) when is_list(errors) do
    Enum.sort_by(errors, fn
      %MissingParameterError{in: loc, name: name} -> {0, loc, name}
      %InvalidParameterError{in: loc, name: name} -> {1, loc, name}
      _ -> {255, nil, nil}
    end)
  end

  defp reason_to_html(%InvalidBodyError{validation_error: verr}) do
    """
    <li>
    <h2>Invalid request body.</h2>

    <pre>#{String.trim_trailing(Exception.message(verr))}</pre>
    </li>
    """
  end

  defp reason_to_html(%InvalidParameterError{in: loc, name: name, validation_error: verr}) do
    """
    <li>
    <h2>Invalid parameter <code>#{name}</code> in <code>#{loc}</code>.</h2>

    <pre>#{String.trim_trailing(Exception.message(verr))}</pre>
    </li>
    """
  end

  defp reason_to_html(%MissingParameterError{in: loc, name: name}) do
    """
    <li>
    <h2>Missing required parameter <code>#{name}</code> in <code>#{loc}</code>.</h2>
    </li>
    """
  end

  defp reason_to_html(%UnsupportedMediaTypeError{media_type: media_type}) do
    """
    <li>
    <h2>Validation for body of type <code>#{media_type}</code> is not supported.</h2>
    </li>
    """
  end

  defp json_encode(payload, opts) do
    case opts[:pretty] do
      true -> Codec.format!(payload)
      _ -> Codec.encode!(payload)
    end
  end

  @css_file :code.priv_dir(:oaskit) |> Path.join("assets/error.min.css")
  @external_resource @css_file
  @css File.read!(@css_file)
  defp css do
    @css
  end
end
