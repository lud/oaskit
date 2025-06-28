defmodule Oaskit.JsonSchema.FormatsTest do
  use ExUnit.Case, async: true

  decimal_bigint = Decimal.new("12345678901234567890")
  decimal_one = Decimal.new("1.0")
  decimal_minus_one = Decimal.new("-1.0")
  decimal_huge = Decimal.new("1.234567890123456789012345678901234")

  test_data = [
    # base64url - Base64url encoded data (RFC4648)
    %{
      format: "base64url",
      valid_inputs: [
        Base.url_encode64(""),
        Base.url_encode64("hello"),
        Base.url_encode64(<<0, 0, 0, 0>>, padding: false)
      ],
      invalid_inputs: ["SGVsbG8+", "SGVsbG8/", "invalid chars!"],
      ignored_inputs: [123, 12.34, true]
    },

    # binary - Any sequence of octets
    %{
      format: "binary",
      valid_inputs: ["hello", "", "any string", "ñoñó", "😀"],
      invalid_inputs: [],
      ignored_inputs: [123, 12.34, true]
    },

    # byte - Base64 encoded data (RFC4648)
    %{
      format: "byte",
      valid_inputs: [Base.encode64(""), Base.encode64("hello"), Base.encode64(<<0, 0, 0, 0>>)],
      invalid_inputs: [
        "invalid base64!",
        Base.encode64("hello", padding: false),
        Base.encode64(<<0, 0, 0, 0>>, padding: false),
        "AA==="
      ],
      ignored_inputs: [123, 12.34, true]
    },

    # char - A single character
    %{
      format: "char",
      valid_inputs: ["a", "1", " ", "😀"],
      invalid_inputs: ["", "ab", "hello"],
      ignored_inputs: [123, 12.34, true]
    },

    # commonmark - Commonmark-formatted text
    %{
      format: "commonmark",
      valid_inputs: ["# Hello", "**bold**", "", "- item 1\n- item 2"],
      invalid_inputs: [],
      ignored_inputs: [123, 12.34, true]
    },

    # date-time - Date and time (RFC3339)
    %{
      format: "date-time",
      valid_inputs: [
        "2023-01-01T12:00:00Z",
        "2023-01-01T12:00:00+02:00",
        "2023-01-01T12:00:00.123Z"
      ],
      invalid_inputs: ["2023-01-01", "12:00:00", "invalid-date", "2023-13-01T12:00:00Z"],
      ignored_inputs: [123, 12.34, true]
    },

    # date - Date (RFC3339)
    %{
      format: "date",
      valid_inputs: ["2023-01-01", "2023-12-31", "1970-01-01"],
      invalid_inputs: [
        "2023-13-01",
        "2023-01-32",
        "01-01-2023",
        "2023-1-1",
        "2023-01-01T12:00:00Z"
      ],
      ignored_inputs: [123, 12.34, true]
    },

    # decimal - Fixed point decimal (string or number)
    %{
      format: "decimal",
      valid_inputs: [
        "123.45",
        "0",
        "-123.45",
        "1000000",
        123.45,
        0,
        -123.45,
        decimal_bigint,
        decimal_huge
      ],
      invalid_inputs: ["abc", "123.45.67", ""],
      ignored_inputs: []
    },

    # decimal128 - Decimal floating-point with 34 significant digits (string or number)
    %{
      format: "decimal128",
      valid_inputs: [
        "123.45",
        "0",
        "-123.45",
        "1.234567890123456789012345678901234",
        123.45,
        0,
        decimal_bigint,
        decimal_huge
      ],
      invalid_inputs: ["abc", "123.45.67", ""],
      ignored_inputs: []
    },

    # double-int - Integer stored in IEEE 754 double without precision loss
    %{
      format: "double-int",
      valid_inputs: [
        123,
        0,
        -123,
        -999_999_999_999_999,
        999_999_999_999_999,
        Decimal.new("999999999999999")
      ],
      invalid_inputs: [12.34, decimal_huge, -1_000_000_000_000_000, 1_000_000_000_000_000],
      ignored_inputs: ["123", "invalid"]
    },

    # double - Double precision floating point
    %{
      format: "double",
      valid_inputs: [
        123.45,
        0,
        -123.45,
        1.797_693_134_862_315_7e+308,
        decimal_bigint,
        decimal_huge
      ],
      invalid_inputs: [],
      ignored_inputs: ["123.45", "invalid"]
    },

    # duration - Duration (RFC3339)
    %{
      format: "duration",
      valid_inputs: ["P1Y2M3DT4H5M6S", "PT1H", "P1D", "PT30S"],
      invalid_inputs: ["1 hour", "invalid", "P1Y2M3D4H5M6S", ""],
      ignored_inputs: [123, 12.34, true]
    },

    # email - Email address (RFC5321)
    %{
      format: "email",
      valid_inputs: ["test@example.com", "user+tag@domain.co.uk", "simple@test.org"],
      invalid_inputs: [
        "invalid",
        "@example.com",
        "test@",
        "test.example.com",
        "test @example.com"
      ],
      ignored_inputs: [123, 12.34, true]
    },

    # float - Single precision floating point
    %{
      format: "float",
      valid_inputs: [123.45, 0, -123.45, 3.402_823_5e+38, decimal_bigint, decimal_huge],
      invalid_inputs: [],
      ignored_inputs: ["123.45", "invalid"]
    },

    # hostname - Host name (RFC1123)
    %{
      format: "hostname",
      valid_inputs: ["example.com", "sub.example.com", "localhost", "host-name"],
      invalid_inputs: ["", "example..com", "example.com.", "-example.com", "example-.com"],
      ignored_inputs: [123, 12.34, true]
    },

    # html - HTML-formatted text
    %{
      format: "html",
      valid_inputs: ["<p>Hello</p>", "<div>content</div>", "", "plain text"],
      invalid_inputs: [],
      ignored_inputs: [123, 12.34, true]
    },

    # TODO validator
    #
    # # http-date - HTTP date (RFC7231)
    # %{
    #   format: "http-date",
    #   valid_inputs: ["Sun, 06 Nov 1994 08:49:37 GMT", "Mon, 01 Jan 2024 00:00:00 GMT"],
    #   invalid_inputs: ["2023-01-01", "invalid date", "Sun, 32 Jan 2024 00:00:00 GMT"],
    #   ignored_inputs: [123, 12.34, true]
    # },

    # TODO(doc) not validated
    #
    # # idn-email - Internationalized email (RFC6531)
    # %{
    #   format: "idn-email",
    #   valid_inputs: ["test@example.com", "ñoño@example.com", "test@ñoño.com"],
    #   invalid_inputs: ["invalid", "@example.com", "test@", "test.example.com"],
    #   ignored_inputs: [123, 12.34, true]
    # },

    # # idn-hostname - Internationalized hostname (RFC5890)
    # %{
    #   format: "idn-hostname",
    #   valid_inputs: ["example.com", "ñoño.com", "测试.com", "localhost"],
    #   invalid_inputs: ["", "example..com", "-example.com"],
    #   ignored_inputs: [123, 12.34, true]
    # },

    # int16 - Signed 16-bit integer
    %{
      format: "int16",
      valid_inputs: [0, 32_767, -32_768, 1000, decimal_one, decimal_minus_one],
      invalid_inputs: [32_768, -32_769, 12.34, decimal_bigint, decimal_huge],
      ignored_inputs: ["123", "invalid"]
    },

    # int32 - Signed 32-bit integer
    %{
      format: "int32",
      valid_inputs: [0, 2_147_483_647, -2_147_483_648, 1000, decimal_one, decimal_minus_one],
      invalid_inputs: [2_147_483_648, -2_147_483_649, 12.34, decimal_bigint, decimal_huge],
      ignored_inputs: ["123", "invalid"]
    },

    # int64 - Signed 64-bit integer (string or number)
    %{
      format: "int64",
      valid_inputs: [
        0,
        9_223_372_036_854_775_807,
        -9_223_372_036_854_775_808,
        "9223372036854775807",
        "0",
        "-1",
        decimal_one,
        decimal_minus_one
      ],
      invalid_inputs: [12.34, "abc", "123.45", decimal_bigint, decimal_huge],
      ignored_inputs: []
    },

    # int8 - Signed 8-bit integer
    %{
      format: "int8",
      valid_inputs: [0, 127, -128, 50, decimal_one, decimal_minus_one],
      invalid_inputs: [128, -129, 12.34, decimal_bigint, decimal_huge],
      ignored_inputs: ["123", "invalid"]
    },

    # ipv4 - IPv4 address (RFC2673)
    %{
      format: "ipv4",
      valid_inputs: ["192.168.1.1", "127.0.0.1", "255.255.255.255", "0.0.0.0"],
      invalid_inputs: ["256.1.1.1", "192.168.1", "192.168.1.1.1", "invalid"],
      ignored_inputs: [123, 12.34, true]
    },

    # ipv6 - IPv6 address (RFC4673)
    %{
      format: "ipv6",
      valid_inputs: ["::1", "2001:db8::1", "::"],
      invalid_inputs: ["192.168.1.1", "invalid", "2001:db8::1::1"],
      ignored_inputs: [123, 12.34, true]
    },

    # iri-reference - IRI reference (RFC3987)
    %{
      format: "iri-reference",
      valid_inputs: ["https://example.com", "/path", "?query", "#fragment"],
      invalid_inputs: [],
      ignored_inputs: [123, 12.34, true]
    },

    # iri - IRI (RFC3987)
    %{
      format: "iri",
      valid_inputs: ["https://example.com", "ftp://test.org"],
      invalid_inputs: ["/relative", "?query", "#fragment"],
      ignored_inputs: [123, 12.34, true]
    },

    # json-pointer - JSON Pointer (RFC6901)
    %{
      format: "json-pointer",
      valid_inputs: ["", "/foo", "/foo/0", "/a~1b", "/a~0b"],
      invalid_inputs: ["foo", "/foo~", "/foo~2"],
      ignored_inputs: [123, 12.34, true]
    },

    # media-range - Media range (RFC9110)
    %{
      format: "media-range",
      valid_inputs: [
        "text/plain",
        "application/json",
        "text/",
        "text/*",
        "*/*",
        "text/plain; charset=utf-8"
      ],
      invalid_inputs: ["invalid", "/json"],
      ignored_inputs: [123, 12.34, true]
    },

    # password - Password hint string
    %{
      format: "password",
      valid_inputs: ["password123", "", "complex!@#$%^&*()"],
      invalid_inputs: [],
      ignored_inputs: [123, 12.34, true]
    },

    # regex - Regular expression (ECMA-262)
    %{
      format: "regex",
      valid_inputs: [".*", "^[a-z]+$", "\\d+", "[abc]", ""],
      invalid_inputs: ["[", "(unclosed", "*"],
      ignored_inputs: [123, 12.34, true]
    },

    # relative-json-pointer - Relative JSON Pointer
    %{
      format: "relative-json-pointer",
      valid_inputs: ["0", "1/foo", "2/bar/0", "0#"],
      invalid_inputs: ["/foo", "-1/foo", "foo"],
      ignored_inputs: [123, 12.34, true]
    },

    # sf-binary - Structured fields byte sequence (RFC8941)
    %{
      format: "sf-binary",
      valid_inputs: [":SGVsbG8=:", "::", ":YWJjZGVmZw==:"],
      invalid_inputs: ["SGVsbG8=", ":$$$^^$$$:", "invalid"],
      ignored_inputs: [123, 12.34, true]
    },

    # sf-boolean - Structured fields boolean (RFC8941)
    %{
      format: "sf-boolean",
      valid_inputs: ["?1", "?0"],
      invalid_inputs: ["true", "false", "?2", "1", "0"],
      ignored_inputs: [123, 12.34, true]
    },

    # sf-decimal - Structured fields decimal (RFC8941)
    %{
      format: "sf-decimal",
      valid_inputs: ["123.45", "0.0", "-123.45", "999999999999.123"],
      invalid_inputs: ["invalid"],
      ignored_inputs: [123.45]
    },

    # sf-integer - Structured fields integer (RFC8941)
    %{
      format: "sf-integer",
      valid_inputs: ["123", "0", "-123", "999999999999999", "1000000000000000"],
      invalid_inputs: ["12.34", "invalid"],
      ignored_inputs: [123, 12.34]
    },

    # sf-string - Structured fields string (RFC8941)
    %{
      format: "sf-string",
      valid_inputs: ["\"hello\"", "\"\"", "\"escaped\\\"quote\""],
      invalid_inputs: ["hello", "\"unclosed", "invalid"],
      ignored_inputs: [123, 12.34, true]
    },

    # sf-token - Structured fields token (RFC8941)
    %{
      format: "sf-token",
      valid_inputs: ["token", "abc123", "valid_token", "*"],
      invalid_inputs: ["\"quoted\"", "invalid token", "123invalid"],
      ignored_inputs: [123, 12.34, true]
    },

    # time - Time (RFC3339)
    %{
      format: "time",
      valid_inputs: ["12:00:00", "23:59:59", "00:00:00", "12:00:00.123"],
      invalid_inputs: ["24:00:00", "12:60:00", "12:00:60", "12:00", "2023-01-01T12:00:00Z"],
      ignored_inputs: [123, 12.34, true]
    },

    # uint16 - Unsigned 16-bit integer
    %{
      format: "uint16",
      valid_inputs: [0, 65_535, 1000, decimal_one],
      invalid_inputs: [-1, 65_536, 12.34, decimal_minus_one],
      ignored_inputs: ["123", "invalid"]
    },

    # uint32 - Unsigned 32-bit integer
    %{
      format: "uint32",
      valid_inputs: [0, 4_294_967_295, 1000, decimal_one],
      invalid_inputs: [-1, 4_294_967_296, 12.34, decimal_minus_one],
      ignored_inputs: ["123", "invalid"]
    },

    # uint64 - Unsigned 64-bit integer (string or number)
    %{
      format: "uint64",
      valid_inputs: [
        0,
        18_446_744_073_709_551_615,
        "18446744073709551615",
        "0",
        "1000",
        decimal_one
      ],
      invalid_inputs: [-1, 12.34, "abc", "-1", decimal_minus_one],
      ignored_inputs: []
    },

    # uint8 - Unsigned 8-bit integer
    %{
      format: "uint8",
      valid_inputs: [0, 255, 128, decimal_one],
      invalid_inputs: [-1, 256, 12.34, decimal_minus_one],
      ignored_inputs: ["123", "invalid"]
    },

    # uri-reference - URI reference (RFC3986)
    %{
      format: "uri-reference",
      valid_inputs: [
        "https://example.com",
        "/path",
        "?query",
        "#fragment",
        "mailto:test@example.com"
      ],
      invalid_inputs: [],
      ignored_inputs: [123, 12.34, true]
    },

    # uri-template - URI Template (RFC6570)
    %{
      format: "uri-template",
      valid_inputs: [
        "/users/{id}",
        "https://api.example.com{/version}/users{?page,limit}",
        "{+path}"
      ],
      invalid_inputs: ["/users/{unclosed", "/users/{invalid}}"],
      ignored_inputs: [123, 12.34, true]
    },

    # uri - URI (RFC3986)
    %{
      format: "uri",
      valid_inputs: [
        "https://example.com",
        "ftp://test.org",
        "mailto:test@example.com",
        "file:///path/to/file"
      ],
      invalid_inputs: ["/relative", "?query", "#fragment", "invalid"],
      ignored_inputs: [123, 12.34, true]
    },

    # uuid - UUID (RFC4122)
    %{
      format: "uuid",
      valid_inputs: [
        "123e4567-e89b-12d3-a456-426614174000",
        "00000000-0000-0000-0000-000000000000"
      ],
      invalid_inputs: [
        "123e4567-e89b-12d3-a456",
        "invalid-uuid",
        "123e4567-e89b-12d3-a456-42661417400g"
      ],
      ignored_inputs: [123, 12.34, true]
    }
  ]

  defp schema_for_format(format) do
    JSV.build!(%{format: format},
      formats: [Oaskit.JsonSchema.Formats | JSV.default_format_validator_modules()]
    )
  end

  defp assert_valid(data, schema) do
    case JSV.validate(data, schema) do
      {:ok, _} ->
        true

      {:error, e} ->
        flunk("""
        format validation failed, expected valid, got error

        DATA
        #{inspect(data)}

        SCHEMA
        #{inspect(schema, pretty: true)}

        ERROR
        #{Exception.message(e)}
        """)
    end
  end

  defp assert_invalid(data, schema, format) do
    case JSV.validate(data, schema) do
      {:error, e} ->
        assert_error_format(e)

      {:ok, _valid} ->
        flunk("""
        format validation failed, expected error, got valid

        DATA
        #{inspect(data)}

        FORMAT
        #{inspect(format)}

        SCHEMA
        #{inspect(schema, pretty: true)}

        """)
    end
  end

  defp assert_ignored(data, schema) do
    assert_valid(data, schema)
  end

  defp assert_error_format(jsv_validation_error) do
    assert %JSV.ValidationError{
             errors: [
               %JSV.Validator.Error{
                 kind: :format
               }
             ]
           } = jsv_validation_error
  end

  Enum.each(test_data, fn tcase ->
    %{
      format: format,
      valid_inputs: valid_inputs,
      invalid_inputs: invalid_inputs,
      ignored_inputs: ignored_inputs
    } =
      tcase

    describe "schema format #{format} -" do
      setup do
        %{schema: schema_for_format(unquote(format))}
      end

      if valid_inputs != [] do
        test "valid inputs", %{schema: schema} do
          Enum.each(unquote(Macro.escape(valid_inputs)), &assert_valid(&1, schema))
        end
      end

      if invalid_inputs != [] do
        test "invalid inputs", %{schema: schema} do
          Enum.each(
            unquote(Macro.escape(invalid_inputs)),
            &assert_invalid(&1, schema, unquote(format))
          )
        end
      end

      if ignored_inputs != [] do
        test "ignored inputs", %{schema: schema} do
          Enum.each(unquote(Macro.escape(ignored_inputs)), &assert_ignored(&1, schema))
        end
      end
    end
  end)
end
