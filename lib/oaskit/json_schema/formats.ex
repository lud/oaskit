defmodule Oaskit.JsonSchema.Formats do
  import JSV.Vocabulary, only: [with_decimal: 1]

  @behaviour JSV.FormatValidator

  @string_formats [
    "base64url",
    "binary",
    "byte",
    "char",
    "commonmark",
    "html",
    "media-range",
    "password"
  ]

  @number_formats [
    "double-int",
    "double",
    "float",
    "int16",
    "int32",
    "int8",
    "uint8",
    "uint16",
    "uint32"
  ]

  # numbers as-is or as string
  @numeric_formats ["decimal", "decimal128", "int64", "uint64"]

  @sf_formats [
    "sf-binary",
    "sf-boolean",
    "sf-decimal",
    "sf-integer",
    "sf-string",
    "sf-token"
  ]

  @all_formats @string_formats ++ @number_formats ++ @numeric_formats ++ @sf_formats

  md_list = fn formats -> formats |> Enum.sort() |> Enum.map(&[" - `", &1, "`\n"]) end

  @moduledoc """
  Implements formats described in https://spec.openapis.org/api/format.json for
  `JSV`'s format validation. Some of the described formats are already
  implemented in JSV directly.

  All schemas used by this library can use those formats in any schema, on top
  of all formats already supported by `JSV`.

  Use the `c:Oaskit.jsv_opts/0` callback to add your own formats.

  The `html` and `commonmark` formats are not validating anything and will
  accept any string.

  ### Number formats

  Number formats apply to the `number` JSON type. So an `int16` format will be
  used on floats and reject them.

  `Decimal` values are supported.

  #{md_list.(@number_formats)}

  ### Numeric formats

  Those apply to numbers and strings, as their value is not representable in
  every programming language.

  `Decimal` values are supported.

  #{md_list.(@numeric_formats)}

  ### String formats

  String formats only apply when the value is a string, much like the default
  JSON schema formats like "date", "uri", _etc._.

  #{md_list.(@string_formats)}

  ### HTTP Structured fields formats

  HTTP structured fields are generally used for headers. While this library does
  not provide header validation yet, they are supported for OpenAPI
  specification compliance.

  #{md_list.(@sf_formats)}
  """

  # TODO provide header validation

  def supported_formats do
    @all_formats
  end

  def applies_to_type?(format, data) when is_binary(data) do
    format in @string_formats or format in @numeric_formats or format in @sf_formats
  end

  def applies_to_type?(format, data) when is_number(data) do
    format in @number_formats or format in @numeric_formats
  end

  with_decimal do
    def applies_to_type?(format, %Decimal{}) do
      format in @number_formats or format in @numeric_formats
    end
  end

  def applies_to_type?(_format, _data) do
    false
  end

  # --

  def validate_cast("base64url", data) do
    case Base.url_decode64(data, padding: false) do
      {:ok, v} -> {:ok, v}
      :error -> {:error, "invalid base64url encoded string"}
    end
  end

  def validate_cast("binary", data) do
    {:ok, data}
  end

  def validate_cast("byte", data) do
    case Base.decode64(data) do
      {:ok, v} -> {:ok, v}
      :error -> {:error, "invalid base64 encoded string"}
    end
  end

  def validate_cast("char", data) do
    case String.length(data) do
      1 -> {:ok, data}
      0 -> {:error, "character cannot be empty"}
      _ -> {:error, "must be a single character"}
    end
  end

  def validate_cast("commonmark", data) do
    # No validation
    {:ok, data}
  end

  def validate_cast("html", data) do
    # No validation
    {:ok, data}
  end

  def validate_cast("media-range", data) do
    case Plug.Conn.Utils.media_type(data) do
      {:ok, _, _, _} -> {:ok, data}
      :error -> {:error, "invalid media range"}
    end
  end

  def validate_cast("password", data) do
    {:ok, data}
  end

  # --

  def validate_cast("decimal", data) do
    str_or_float(data, "invalid decimal format")
  end

  def validate_cast("decimal128", data) do
    str_or_float(data, "invalid decimal format")
  end

  def validate_cast("double-int", data) when is_integer(data) do
    integer_in_range(data, -999_999_999_999_999, 999_999_999_999_999)
  end

  with_decimal do
    def validate_cast("double-int", %Decimal{} = data) do
      if Decimal.integer?(data) do
        integer_in_range(Decimal.to_integer(data), -999_999_999_999_999, 999_999_999_999_999)
      else
        {:error, "invalid integer #{inspect(data)}"}
      end
    end
  end

  def validate_cast("double-int", data) do
    {:error, "invalid integer #{inspect(data)}"}
  end

  def validate_cast("double", data) do
    {:ok, to_float(data)}
  end

  def validate_cast("float", data) do
    {:ok, to_float(data)}
  end

  def validate_cast("int16", data) do
    integer_in_range(data, -32_768, 32_767)
  end

  def validate_cast("int32", data) do
    integer_in_range(data, -2_147_483_648, 2_147_483_647)
  end

  def validate_cast("int64", data) when is_binary(data) do
    case Integer.parse(data) do
      {int, ""} -> validate_cast("int64", int)
      _ -> {:error, "invalid integer"}
    end
  end

  def validate_cast("int64", data) do
    integer_in_range(data, -9_223_372_036_854_775_808, 9_223_372_036_854_775_807)
  end

  def validate_cast("int8", data) do
    integer_in_range(data, -128, 127)
  end

  def validate_cast("uint8", data) do
    integer_in_range(data, 0, 255)
  end

  def validate_cast("uint16", data) do
    integer_in_range(data, 0, 65_535)
  end

  def validate_cast("uint32", data) do
    integer_in_range(data, 0, 4_294_967_295)
  end

  def validate_cast("uint64", data) when is_binary(data) do
    case Integer.parse(data) do
      {int, ""} -> validate_cast("uint64", int)
      _ -> {:error, "invalid integer"}
    end
  end

  def validate_cast("uint64", data) do
    integer_in_range(data, 0, 18_446_744_073_709_551_615)
  end

  # --

  def validate_cast("sf-binary", data) do
    expect_sf_item(data, :byte_sequence)
  end

  def validate_cast("sf-boolean", data) do
    expect_sf_item(data, :boolean)
  end

  def validate_cast("sf-decimal", data) do
    expect_sf_item(data, :decimal)
  end

  def validate_cast("sf-integer", data) do
    expect_sf_item(data, :integer)
  end

  def validate_cast("sf-string", data) do
    expect_sf_item(data, :string)
  end

  def validate_cast("sf-token", data) do
    expect_sf_item(data, :token)
  end

  # -- Helpers ----------------------------------------------------------------

  defp str_or_float(data, _errmsg) when is_number(data) do
    {:ok, data}
  end

  defp str_or_float(data, errmsg) when is_binary(data) do
    case Float.parse(data) do
      {v, ""} -> {:ok, v}
      _ -> {:error, errmsg}
    end
  end

  with_decimal do
    defp str_or_float(%Decimal{} = data, _errmsg) do
      {:ok, Decimal.to_float(data)}
    end
  end

  defp to_float(data) when is_float(data) do
    data
  end

  defp to_float(data) when is_integer(data) do
    1.0 * data
  end

  with_decimal do
    defp to_float(%Decimal{} = data) do
      Decimal.to_float(data)
    end
  end

  defp integer_in_range(n, min, max) when is_integer(n) and n >= min and n <= max do
    {:ok, n}
  end

  with_decimal do
    defp integer_in_range(%Decimal{} = n, min, max) do
      if Decimal.integer?(n) do
        integer_in_range(Decimal.to_integer(n), min, max)
      else
        {:error, "not an integer representation"}
      end
    end
  end

  defp integer_in_range(n, _min, _max) when is_integer(n) do
    {:error, "out of range"}
  end

  defp integer_in_range(_n, _min, _max) do
    {:error, "not an integer"}
  end

  defp expect_sf_item(data, expected_type) do
    case Texture.HttpStructuredField.parse_item(data) do
      {:ok, {^expected_type, value, _}} -> {:ok, value}
      {:ok, _} -> {:error, "invalid structured field type"}
      {:error, {errmsg, _}} -> {:error, errmsg}
    end
  end
end
