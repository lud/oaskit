defmodule OpenApify.Parsers.HttpStructuredFieldTest do
  alias OpenApify.Parsers.HttpStructuredField
  use ExUnit.Case, async: true

  defp unwrap!(v) do
    case v do
      {:ok, value} -> value
      other -> flunk("got #{inspect(other)}")
    end
  end

  describe "integers" do
    test "parses simple integer" do
      assert {:integer, 42, []} == unwrap!(HttpStructuredField.parse_sf_item("42"))
    end

    test "parses integer 5" do
      assert {:integer, 5, []} == unwrap!(HttpStructuredField.parse_sf_item("5"))
    end

    test "parses integer with parameters" do
      assert {:integer, 5, [{"foo", {:token, "bar"}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("5; foo=bar"))
    end

    test "parses integer with boolean parameter" do
      assert {:integer, 1, [{"a", {:boolean, true}}, {"b", {:boolean, false}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("1; a; b=?0"))
    end

    test "parses negative integer" do
      assert {:integer, -42, []} == unwrap!(HttpStructuredField.parse_sf_item("-42"))
    end

    test "parses zero" do
      assert {:integer, 0, []} == unwrap!(HttpStructuredField.parse_sf_item("0"))
    end

    test "parses large integers" do
      # Those are the min/max values that must be supported
      assert {:integer, 999_999_999_999_999, []} ==
               unwrap!(HttpStructuredField.parse_sf_item("999999999999999"))

      assert {:integer, -999_999_999_999_999, []} ==
               unwrap!(HttpStructuredField.parse_sf_item("-999999999999999"))

      # We do not fail if values are larger as Elixir supports them
    end
  end

  describe "decimals" do
    test "parses simple decimal" do
      assert {:decimal, 4.5, []} == unwrap!(HttpStructuredField.parse_sf_item("4.5"))
    end

    test "parses decimal with rating" do
      assert {:decimal, 1.5, []} == unwrap!(HttpStructuredField.parse_sf_item("1.5"))
    end

    test "parses negative decimal" do
      assert {:decimal, -1.5, []} == unwrap!(HttpStructuredField.parse_sf_item("-1.5"))
    end

    test "parses decimal with three fractional digits" do
      assert {:decimal, 123.456, []} == unwrap!(HttpStructuredField.parse_sf_item("123.456"))
    end

    test "parses decimal with trailing zeros" do
      assert {:decimal, 5.230, []} == unwrap!(HttpStructuredField.parse_sf_item("5.230"))
    end

    test "parses negative decimal with trailing zeros" do
      assert {:decimal, -0.40, []} == unwrap!(HttpStructuredField.parse_sf_item("-0.40"))
    end

    test "parses zero decimal" do
      assert {:decimal, +0.0, []} == unwrap!(HttpStructuredField.parse_sf_item("0.0"))
    end

    test "parses negative zero decimal" do
      assert {:decimal, -0.0, []} == unwrap!(HttpStructuredField.parse_sf_item("-0.0"))
    end

    test "invalid decimal, two dots" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("1.234.5")
    end
  end

  describe "strings" do
    test "parses simple string" do
      assert {:string, "hello world", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"hello world"}))
    end

    test "parses empty string" do
      assert {:string, "", []} == unwrap!(HttpStructuredField.parse_sf_item(~S{""}))
    end

    test "parses string with escaped quotes" do
      assert {:string, "say \"hello\"", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"say \"hello\""}))
    end

    test "parses string with escaped backslash" do
      assert {:string, "path\\to\\file", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"path\\to\\file"}))
    end

    test "parses string Applepie" do
      assert {:string, "Applepie", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"Applepie"}))
    end

    test "parses string with URI" do
      assert {:string, "https://foo.example.com/", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"https://foo.example.com/"}))
    end

    test "invalid string, unfinished quote (unescaped quote)" do
      assert {:error, _} = HttpStructuredField.parse_sf_item(~S{"hello world})
    end
  end

  describe "tokens" do
    test "parses simple token" do
      assert {:token, "sugar", []} == unwrap!(HttpStructuredField.parse_sf_item("sugar"))
    end

    test "parses token tea" do
      assert {:token, "tea", []} == unwrap!(HttpStructuredField.parse_sf_item("tea"))
    end

    test "parses token rum" do
      assert {:token, "rum", []} == unwrap!(HttpStructuredField.parse_sf_item("rum"))
    end

    test "parses token with numbers and special chars" do
      assert {:token, "foo123/456", []} ==
               unwrap!(HttpStructuredField.parse_sf_item("foo123/456"))
    end

    test "parses token abc" do
      assert {:token, "abc", []} == unwrap!(HttpStructuredField.parse_sf_item("abc"))
    end

    test "parses token cde_456" do
      assert {:token, "cde_456", []} == unwrap!(HttpStructuredField.parse_sf_item("cde_456"))
    end

    test "parses token ghi" do
      assert {:token, "ghi", []} == unwrap!(HttpStructuredField.parse_sf_item("ghi"))
    end

    test "parses token l" do
      assert {:token, "l", []} == unwrap!(HttpStructuredField.parse_sf_item("l"))
    end

    test "parses token w" do
      assert {:token, "w", []} == unwrap!(HttpStructuredField.parse_sf_item("w"))
    end

    test "parses token joy" do
      assert {:token, "joy", []} == unwrap!(HttpStructuredField.parse_sf_item("joy"))
    end

    test "parses token sadness" do
      assert {:token, "sadness", []} == unwrap!(HttpStructuredField.parse_sf_item("sadness"))
    end

    test "parses token starting with asterisk" do
      assert {:token, "*foo", []} == unwrap!(HttpStructuredField.parse_sf_item("*foo"))
    end

    test "invalid token (starts with digit)" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("123abc")
    end
  end

  describe "byte sequences" do
    test "parses simple byte sequence" do
      assert {:byte_sequence, "pretend this is binary content.", []} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(
                   ":cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:"
                 )
               )
    end

    test "parses byte sequence w4ZibGV0w6ZydGU=" do
      # This decodes to something like "Ælet¦rte" in some encoding
      expected_bytes = Base.decode64!("w4ZibGV0w6ZydGU=")

      assert {:byte_sequence, expected_bytes, []} ==
               unwrap!(HttpStructuredField.parse_sf_item(":w4ZibGV0w6ZydGU=:"))
    end

    test "parses empty byte sequence" do
      assert {:byte_sequence, "", []} == unwrap!(HttpStructuredField.parse_sf_item("::"))
    end

    test "invalid base64" do
      assert {:error, _} = HttpStructuredField.parse_sf_item(":invalid@base64:")
    end
  end

  describe "booleans" do
    test "parses true boolean" do
      assert {:boolean, true, []} == unwrap!(HttpStructuredField.parse_sf_item("?1"))
    end

    test "parses false boolean" do
      assert {:boolean, false, []} == unwrap!(HttpStructuredField.parse_sf_item("?0"))
    end

    test "invalid boolean" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("?2")
    end
  end

  describe "items with parameters" do
    test "parses integer with string parameter" do
      assert {:integer, 2, [{"foourl", {:string, "https://foo.example.com/"}}]} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item("2; foourl=\"https://foo.example.com/\"")
               )
    end

    test "parses token with multiple parameters" do
      assert {:token, "abc", [{"a", {:integer, 1}}, {"b", {:integer, 2}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("abc;a=1;b=2"))
    end

    test "parses item with boolean parameters" do
      assert {:integer, 1, [{"a", {:boolean, true}}, {"b", {:boolean, false}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("1; a; b=?0"))
    end

    test "parses item with decimal parameter" do
      assert {:token, "ghi", [{"jk", {:integer, 4}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("ghi;jk=4"))
    end

    test "parses item with string paramete" do
      assert {:token, "l", [{"q", {:string, "9"}}, {"r", {:token, "w"}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("l;q=\"9\";r=w"))
    end

    test "complex URL as parameter" do
      assert {:integer, 2, [{"foourl", {:string, "https://foo.example.com?a=1;b=2/"}}]} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(
                   "2; foourl=\"https://foo.example.com?a=1;b=2/\""
                 )
               )
    end
  end

  describe "lists" do
    test "parses simple token list" do
      assert [
               {:token, "sugar", []},
               {:token, "tea", []},
               {:token, "rum", []}
             ] == unwrap!(HttpStructuredField.parse_sf_list("sugar, tea, rum"))
    end

    test "parses list with parameters" do
      assert [
               {:token, "abc",
                [{"a", {:integer, 1}}, {"b", {:integer, 2}}, {"cde_456", {:boolean, true}}]}
             ] == unwrap!(HttpStructuredField.parse_sf_list("abc;a=1;b=2; cde_456"))
    end

    test "multiple items list with parameters" do
      assert [
               {:token, "abc",
                [{"a", {:integer, 1}}, {"b", {:integer, 2}}, {"cde_456", {:boolean, true}}]},
               {:inner_list,
                [
                  {:token, "ghi", [{"jk", {:integer, 4}}]},
                  {:token, "l", []}
                ], [{"q", {:string, "9"}}, {"r", {:token, "w"}}]}
             ] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list(
                   ~S{abc;a=1;b=2; cde_456, (ghi;jk=4 l);q="9";r=w}
                 )
               )
    end

    test "parses empty list" do
      # According to the documentation:
      #
      #     An empty List is denoted by not serializing the field at all. This
      #     implies that fields defined as Lists have a default empty value.
      #
      # So we expect an error for the empty string
      assert {:error, {:empty, "     \t        "}} =
               HttpStructuredField.parse_sf_list("     \t        ")
    end
  end

  describe "inner lists" do
    defp parse_inner_list!(input) do
      case HttpStructuredField.parse_sf_list(input) do
        {:ok, [found]} ->
          found

        other ->
          flunk("""
          Could not parse inner list, got: #{inspect(other)}
          """)
      end
    end

    test "parses simple inner list" do
      assert {:inner_list,
              [
                {:string, "foo", []},
                {:string, "bar", []}
              ], []} = parse_inner_list!(~S{("foo" "bar")})
    end

    test "parses inner list with single item" do
      assert {:inner_list,
              [
                {:string, "baz", []}
              ], []} = parse_inner_list!("(\"baz\")")
    end

    test "parses inner list with multiple items" do
      assert {:inner_list,
              [
                {:string, "bat", []},
                {:string, "one", []}
              ], []} = parse_inner_list!(~S{("bat" "one")})
    end

    test "parses empty inner list" do
      assert {:inner_list, [], []} = parse_inner_list!("()")
    end

    test "parses inner list with parameters" do
      assert {:inner_list,
              [
                {:string, "foo", [{"a", {:integer, 1}}, {"b", {:integer, 2}}]}
              ], [{"lvl", {:integer, 5}}]} = parse_inner_list!("(\"foo\"; a=1;b=2);lvl=5")
    end

    test "parses inner list with tokens and parameters" do
      assert {:inner_list,
              [
                {:string, "bar", []},
                {:string, "baz", []}
              ], [{"lvl", {:integer, 1}}]} = parse_inner_list!(~S{("bar" "baz");lvl=1})
    end

    test "parses inner list with integers" do
      assert {:inner_list,
              [
                {:integer, 1, []},
                {:integer, 2, []}
              ], []} = parse_inner_list!("(1 2)")
    end

    test "parses inner list with tokens" do
      assert {:inner_list,
              [
                {:token, "joy", []},
                {:token, "sadness", []}
              ], []} = parse_inner_list!("(joy sadness)")
    end

    test "parses inner list with integers and parameters" do
      assert {:inner_list,
              [
                {:integer, 5, []},
                {:integer, 6, []}
              ], [{"valid", {:boolean, true}}]} = parse_inner_list!("(5 6);valid")
    end
  end

  describe "lists with inner lists" do
    test "parses list of inner lists of strings" do
      assert [
               {:inner_list,
                [
                  {:string, "foo", []},
                  {:string, "bar", []}
                ], []},
               {:inner_list,
                [
                  {:string, "baz", []}
                ], []},
               {:inner_list,
                [
                  {:string, "bat", []},
                  {:string, "one", []}
                ], []},
               {:inner_list, [], []}
             ] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list(~S{("foo" "bar"), ("baz"), ("bat" "one"), ()})
               )
    end

    test "parses list of inner lists with parameters" do
      assert [
               {:inner_list,
                [
                  {:string, "foo", [{"a", {:integer, 1}}, {"b", {:integer, 2}}]}
                ], [{"lvl", {:integer, 5}}]},
               {:inner_list,
                [
                  {:string, "bar", []},
                  {:string, "baz", []}
                ], [{"lvl", {:integer, 1}}]}
             ] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list(
                   ~S{("foo"; a=1;b=2);lvl=5, ("bar" "baz");lvl=1}
                 )
               )
    end

    test "parses mixed list with tokens and inner lists" do
      assert [
               {:inner_list,
                [
                  {:token, "ghi", [{"jk", {:integer, 4}}]},
                  {:token, "l", []}
                ], []},
               {:token, "l", [{"q", {:string, "9"}}, {"r", {:token, "w"}}]}
             ] == unwrap!(HttpStructuredField.parse_sf_list("(ghi;jk=4 l), l;q=\"9\";r=w"))
    end
  end

  describe "dictionaries" do
    test "parses simple dictionary" do
      assert [
               {"en", {:string, "Applepie", []}},
               {"da", {:byte_sequence, "hello", []}}
             ] ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary(
                   "en=\"Applepie\", da=:#{Base.encode64("hello")}:"
                 )
               )
    end

    test "parses dictionary with boolean values" do
      assert [
               {"a", {:boolean, false, []}},
               {"b", {:boolean, true, []}},
               {"c", {:boolean, true, [{"foo", {:token, "bar"}}]}}
             ] == unwrap!(HttpStructuredField.parse_sf_dictionary("a=?0, b, c; foo=bar"))
    end

    test "parses dictionary with decimal and inner list" do
      assert [
               {"rating", {:decimal, 1.5, []}},
               {"feelings",
                {:inner_list,
                 [
                   {:token, "joy", []},
                   {:token, "sadness", []}
                 ], []}}
             ] ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary("rating=1.5, feelings=(joy sadness)")
               )
    end

    test "parses dictionary with mix of items and inner lists" do
      assert [
               {"a",
                {:inner_list,
                 [
                   {:integer, 1, []},
                   {:integer, 2, []}
                 ], []}},
               {"b", {:integer, 3, []}},
               {"c", {:integer, 4, [{"aa", {:token, "bb"}}]}},
               {"d",
                {:inner_list,
                 [
                   {:integer, 5, []},
                   {:integer, 6, []}
                 ], [{"valid", {:boolean, true}}]}}
             ] ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary("a=(1 2), b=3, c=4;aa=bb, d=(5 6);valid")
               )
    end

    test "parses simple key-value dictionary" do
      assert [
               {"foo", {:integer, 1, []}},
               {"bar", {:integer, 2, []}}
             ] == unwrap!(HttpStructuredField.parse_sf_dictionary("foo=1, bar=2"))
    end

    test "parses empty dictionary" do
      assert {:error, {:empty, "   \t   "}} = HttpStructuredField.parse_sf_dictionary("   \t   ")
    end
  end

  describe "edge cases for dicts" do
    test "dictionary with key= without value" do
      assert {:error, _} = HttpStructuredField.parse_sf_dictionary("a=")
    end

    test "dictionary with duplicate keys - last wins" do
      # RFC 8941: When duplicate Dictionary keys are encountered, all but the last instance are ignored
      assert [
               {"foo", {:integer, 2, []}}
             ] == unwrap!(HttpStructuredField.parse_sf_dictionary("foo=1, foo=2"))
    end

    test "dictionary with very long key (edge case)" do
      # RFC 8941: Parsers MUST support keys with at least 64 characters
      long_key = String.duplicate("a", 64)

      assert [
               {long_key, {:integer, 1, []}}
             ] == unwrap!(HttpStructuredField.parse_sf_dictionary("#{long_key}=1"))
    end

    test "dictionary with maximum items (edge case)" do
      # RFC 8941: Parsers MUST support Dictionaries containing at least 1024 key/value pairs
      # Test with a reasonable subset to avoid overly long test
      pairs =
        for i <- 1..100 do
          "k#{i}=#{i}"
        end

      dict_string = Enum.join(pairs, ", ")
      result = unwrap!(HttpStructuredField.parse_sf_dictionary(dict_string))
      assert 100 == length(result)
    end

    test "dictionary with whitespace around delimiters" do
      assert [
               {"a", {:integer, 1, []}},
               {"b", {:integer, 2, []}}
             ] == unwrap!(HttpStructuredField.parse_sf_dictionary("a=1 , b=2"))
    end

    test "dictionary with trailing comma (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_dictionary("a=1, b=2,")
    end

    test "dictionary with consecutive commas (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_dictionary("a=1,, b=2")
    end

    test "dictionary key with invalid characters" do
      assert {:error, _} = HttpStructuredField.parse_sf_dictionary("UPPER=1")
      assert {:error, _} = HttpStructuredField.parse_sf_dictionary("key with space=1")
      assert {:error, _} = HttpStructuredField.parse_sf_dictionary("123key=1")
    end

    test "dictionary with complex nested parameters" do
      assert [
               {"a", {:integer, 1, [{"x", {:boolean, true}}, {"y", {:string, "test"}}]}},
               {"b", {:inner_list, [{:integer, 2, []}], [{"z", {:decimal, 3.14}}]}}
             ] ==
               unwrap!(HttpStructuredField.parse_sf_dictionary("a=1;x;y=\"test\", b=(2);z=3.14"))
    end
  end

  describe "edge cases for integers" do
    test "integer with leading zeros" do
      # RFC 8941: Leading zeros may not be preserved, but should parse
      assert {:integer, 42, []} == unwrap!(HttpStructuredField.parse_sf_item("0042"))
      assert {:integer, -42, []} == unwrap!(HttpStructuredField.parse_sf_item("-0042"))
    end

    test "signed zero" do
      # RFC 8941: Signed zero may not be preserved
      assert {:integer, 0, []} == unwrap!(HttpStructuredField.parse_sf_item("-0"))
    end
  end

  describe "edge cases for decimals" do
    test "decimal boundaries" do
      # RFC 8941: integer component has at most 12 digits, fractional at most 3

      # We must ensure those values are supported
      assert {:decimal, 999_999_999_999.999, []} ==
               unwrap!(HttpStructuredField.parse_sf_item("999999999999.999"))

      assert {:decimal, -999_999_999_999.999, []} ==
               unwrap!(HttpStructuredField.parse_sf_item("-999999999999.999"))

      # Elixir supports larger values so we do not fail in that case
    end

    test "decimal with trailing zeros in fractional part" do
      assert {:decimal, 5.230, []} == unwrap!(HttpStructuredField.parse_sf_item("5.230"))
      assert {:decimal, -0.40, []} == unwrap!(HttpStructuredField.parse_sf_item("-0.40"))
    end

    test "decimal ending with dot only (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("123.")
    end

    test "decimal with multiple dots (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("1.2.3")
    end
  end

  describe "edge cases for strings" do
    test "string with maximum length" do
      # RFC 8941: Parsers MUST support Strings with at least 1024 characters
      long_string = String.duplicate("a", 1024)
      quoted_string = "\"#{long_string}\""

      assert {:string, long_string, []} ==
               unwrap!(HttpStructuredField.parse_sf_item(quoted_string))
    end

    test "string with all allowed escape sequences" do
      assert {:string, "quote: \" backslash: \\", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"quote: \" backslash: \\"}))
    end

    test "string with invalid escape sequences" do
      assert {:error, _} = HttpStructuredField.parse_sf_item(~S{"invalid \x escape"})
      assert {:error, _} = HttpStructuredField.parse_sf_item(~S{"invalid \n escape"})
      assert {:error, _} = HttpStructuredField.parse_sf_item(~S{"invalid \t escape"})
    end

    test "string with unescaped quote in middle (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_item(~S{"hello"world"})
    end

    test "string with control characters (invalid)" do
      # RFC 8941: String should not contain characters in range %x00-1f or %x7f-ff
      assert {:error, _} = HttpStructuredField.parse_sf_item("\"hello\x00world\"")
      assert {:error, _} = HttpStructuredField.parse_sf_item("\"hello\x1fworld\"")
    end

    test "unterminated string (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_item(~S{"unterminated})
    end
  end

  describe "edge cases for tokens" do
    test "token with maximum length" do
      # RFC 8941: Parsers MUST support Tokens with at least 512 characters
      long_token = String.duplicate("a", 512)
      assert {:token, long_token, []} == unwrap!(HttpStructuredField.parse_sf_item(long_token))
    end

    test "token with all allowed characters" do
      # Test various tchar characters and ":" "/"
      assert {:token, "abc123_-.*:/%", []} ==
               unwrap!(HttpStructuredField.parse_sf_item("abc123_-.*:/%"))
    end

    test "token starting with invalid characters" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("123invalid")
      assert {:error, _} = HttpStructuredField.parse_sf_item("-invalid")
      assert {:error, _} = HttpStructuredField.parse_sf_item(".invalid")
    end

    test "token with uppercase letters (invalid in some contexts)" do
      # While uppercase ALPHA is allowed in first position, test edge case
      assert {:token, "ValidToken", []} ==
               unwrap!(HttpStructuredField.parse_sf_item("ValidToken"))
    end
  end

  describe "edge cases for byte sequences" do
    test "byte sequence with maximum length" do
      # RFC 8941: Parsers MUST support Byte Sequences with at least 16384 octets after decoding
      # Test a reasonable subset
      large_data = String.duplicate("a", 1000)
      encoded = Base.encode64(large_data)

      assert {:byte_sequence, large_data, []} ==
               unwrap!(HttpStructuredField.parse_sf_item(":#{encoded}:"))
    end

    test "byte sequence with padding variations" do
      # Test different padding scenarios
      # With padding
      assert {:byte_sequence, "sure.", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(":c3VyZS4=:"))
    end

    test "byte sequence with invalid base64 characters" do
      assert {:error, _} = HttpStructuredField.parse_sf_item(":invalid@chars:")
      assert {:error, _} = HttpStructuredField.parse_sf_item(":contains spaces:")
    end

    test "byte sequence missing closing colon" do
      assert {:error, _} = HttpStructuredField.parse_sf_item(":dGVzdA==")
    end

    test "byte sequence with only one colon" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("dGVzdA==:")
    end
  end

  describe "edge cases for booleans" do
    test "invalid boolean values" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("?2")
      assert {:error, _} = HttpStructuredField.parse_sf_item("?true")
      assert {:error, _} = HttpStructuredField.parse_sf_item("?false")
      assert {:error, _} = HttpStructuredField.parse_sf_item("??1")
      assert {:error, _} = HttpStructuredField.parse_sf_item("?")
    end
  end

  describe "edge cases for parameters" do
    test "parameter with maximum count" do
      # RFC 8941: Parsers MUST support at least 256 parameters
      # Test a reasonable subset
      params =
        for i <- 1..50 do
          "p#{i}=#{i}"
        end

      param_string = Enum.join(params, ";")
      input = "token;#{param_string}"
      assert {:token, "token", parameters} = unwrap!(HttpStructuredField.parse_sf_item(input))
      assert 50 == length(parameters)
    end

    test "parameter key with maximum length" do
      # RFC 8941: parameter keys with at least 64 characters
      long_key = String.duplicate("a", 64)

      assert {:integer, 1, [{long_key, {:integer, 2}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("1;#{long_key}=2"))
    end

    test "parameter with duplicate keys - last wins" do
      # RFC 8941: When duplicate parameter keys are encountered, all but the last instance are ignored
      assert {:integer, 1, [{"foo", {:integer, 3}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("1;foo=1;foo=2;foo=3"))
    end

    test "parameter key with invalid characters" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("1;UPPER=2")
      assert {:error, _} = HttpStructuredField.parse_sf_item("1;123=2")
      assert {:error, _} = HttpStructuredField.parse_sf_item("1;-invalid=2")
    end

    test "parameter without value (boolean true)" do
      assert {:integer, 1, [{"flag", {:boolean, true}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("1;flag"))
    end

    test "parameter with empty key" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("1;=value")
    end
  end

  describe "edge cases for lists" do
    test "list with maximum members" do
      # RFC 8941: Parsers MUST support Lists containing at least 1024 members
      # Test with reasonable subset
      items =
        for i <- 1..100 do
          "#{i}"
        end

      list_string = Enum.join(items, ", ")
      result = unwrap!(HttpStructuredField.parse_sf_list(list_string))
      assert 100 == length(result)
    end

    test "list with trailing comma (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_list("1, 2, 3,")
    end

    test "list with consecutive commas (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_list("1,, 2")
    end

    test "list with only whitespace between items" do
      # Should fail - comma is required
      assert {:error, _} = HttpStructuredField.parse_sf_list("1 2 3")
    end
  end

  describe "edge cases for inner lists" do
    test "inner list with maximum members" do
      # RFC 8941: Parsers MUST support Inner Lists containing at least 256 members
      # Test with reasonable subset
      items =
        for i <- 1..50 do
          "#{i}"
        end

      inner_list_string = "(#{Enum.join(items, " ")})"
      {:inner_list, result, []} = parse_inner_list!(inner_list_string)
      assert length(result) == 50
    end

    test "inner list with mixed whitespace" do
      assert {:inner_list,
              [
                {:integer, 1, []},
                {:integer, 2, []},
                {:integer, 3, []}
              ], []} = parse_inner_list!("(1  2   3)")
    end

    test "inner list with tab characters" do
      # RFC allows tab characters for field line concatenation
      assert {:inner_list,
              [
                {:integer, 1, []},
                {:integer, 2, []}
              ], []} = parse_inner_list!("(1\t2)")
    end

    test "inner list without closing parenthesis (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_list("(1 2")
    end

    test "inner list without opening parenthesis (invalid)" do
      assert {:error, _} = HttpStructuredField.parse_sf_list("1 2)")
    end

    test "nested inner lists (invalid)" do
      # Inner lists cannot contain other inner lists
      assert {:error, _} = HttpStructuredField.parse_sf_list("((1))")
    end
  end

  describe "whitespace and formatting edge cases" do
    test "excessive whitespace handling" do
      assert [
               {"a", {:integer, 1, []}},
               {"b", {:integer, 2, []}}
             ] == unwrap!(HttpStructuredField.parse_sf_dictionary("   a=1   ,   b=2  "))
    end

    test "tab characters in various positions" do
      # Tabs should be treated like spaces in most contexts
      assert [
               {"a", {:integer, 1, []}}
             ] == unwrap!(HttpStructuredField.parse_sf_dictionary("\t\ta=1\t"))
    end

    test "mixed whitespace types" do
      assert {:integer, 1, [{"a", {:integer, 2}}]} ==
               unwrap!(HttpStructuredField.parse_sf_item(" \t  1 ;\t a=2 \t \t "))
    end
  end

  describe "malformed input edge cases" do
    test "completely invalid input" do
      assert {:error, _} = HttpStructuredField.parse_sf_item("@#$%&*()")
      assert {:error, _} = HttpStructuredField.parse_sf_list("@#$%")
      assert {:error, _} = HttpStructuredField.parse_sf_dictionary("@#$%")
    end

    test "partial valid input" do
      # Valid start but becomes invalid
      assert {:error, _} = HttpStructuredField.parse_sf_item("123abc@#$")
      assert {:error, _} = HttpStructuredField.parse_sf_item("\"hello@#$")
    end

    test "unicode characters (invalid)" do
      # RFC 8941: Strings are ASCII only
      assert {:error, _} = HttpStructuredField.parse_sf_item("\"héllo\"")
      assert {:error, _} = HttpStructuredField.parse_sf_item("tökën")
    end
  end

  describe "with unwrap: true option" do
    test "unwrapped integers" do
      assert {42, []} == unwrap!(HttpStructuredField.parse_sf_item("42", unwrap: true))

      assert {-999_999_999_999_999, []} ==
               unwrap!(HttpStructuredField.parse_sf_item("-999999999999999", unwrap: true))

      assert {5, [{"foo", "bar"}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("5; foo=bar", unwrap: true))
    end

    test "unwrapped decimals" do
      assert {4.5, []} == unwrap!(HttpStructuredField.parse_sf_item("4.5", unwrap: true))
      assert {-1.5, []} == unwrap!(HttpStructuredField.parse_sf_item("-1.5", unwrap: true))

      assert {123.456, [{"precision", 3}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("123.456; precision=3", unwrap: true))
    end

    test "unwrapped strings" do
      assert {"hello world", []} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"hello world"}, unwrap: true))

      assert {"", []} == unwrap!(HttpStructuredField.parse_sf_item(~S{""}, unwrap: true))

      assert {"Applepie", [{"lang", "en"}]} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"Applepie"; lang=en}, unwrap: true))
    end

    test "unwrapped tokens" do
      assert {"sugar", []} == unwrap!(HttpStructuredField.parse_sf_item("sugar", unwrap: true))

      assert {"foo123/456", []} ==
               unwrap!(HttpStructuredField.parse_sf_item("foo123/456", unwrap: true))

      assert {"abc", [{"a", 1}, {"b", 2}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("abc;a=1;b=2", unwrap: true))
    end

    test "unwrapped byte sequences" do
      assert {"pretend this is binary content.", []} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(
                   ":cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:",
                   unwrap: true
                 )
               )

      assert {"", []} == unwrap!(HttpStructuredField.parse_sf_item("::", unwrap: true))
      expected_bytes = Base.decode64!("w4ZibGV0w6ZydGU=")

      assert {expected_bytes, [{"encoding", "utf8"}]} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(":w4ZibGV0w6ZydGU=:; encoding=utf8",
                   unwrap: true
                 )
               )
    end

    test "unwrapped booleans" do
      assert {true, []} == unwrap!(HttpStructuredField.parse_sf_item("?1", unwrap: true))
      assert {false, []} == unwrap!(HttpStructuredField.parse_sf_item("?0", unwrap: true))

      assert {true, [{"flag", "active"}]} ==
               unwrap!(HttpStructuredField.parse_sf_item("?1; flag=active", unwrap: true))
    end

    test "unwrapped inner lists" do
      assert [{[{"foo", []}, {"bar", []}], []}] ==
               unwrap!(HttpStructuredField.parse_sf_list(~S{("foo" "bar")}, unwrap: true))

      assert [{[], []}] == unwrap!(HttpStructuredField.parse_sf_list("()", unwrap: true))

      assert [{[{1, [{"a", 2}]}, {3, []}], [{"lvl", 5}]}] ==
               unwrap!(HttpStructuredField.parse_sf_list("(1;a=2 3);lvl=5", unwrap: true))
    end

    test "unwrapped lists" do
      assert [{"sugar", []}, {"tea", []}, {"rum", []}] ==
               unwrap!(HttpStructuredField.parse_sf_list("sugar, tea, rum", unwrap: true))

      assert [{"abc", [{"a", 1}]}] ==
               unwrap!(HttpStructuredField.parse_sf_list("abc;a=1", unwrap: true))

      assert [{"abc", [{"flag", true}]}, {[{"ghi", []}, {"l", []}], [{"q", "9"}]}] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list(~S{abc;flag, (ghi l);q="9"}, unwrap: true)
               )
    end

    test "unwrapped dictionaries" do
      assert [{"foo", {1, []}}, {"bar", {2, []}}] ==
               unwrap!(HttpStructuredField.parse_sf_dictionary("foo=1, bar=2", unwrap: true))

      assert [{"a", {false, []}}, {"b", {true, []}}] ==
               unwrap!(HttpStructuredField.parse_sf_dictionary("a=?0, b", unwrap: true))

      assert [{"rating", {1.5, []}}, {"feelings", {[{"joy", []}, {"sadness", []}], []}}] ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary("rating=1.5, feelings=(joy sadness)",
                   unwrap: true
                 )
               )
    end
  end

  describe "with maps: true option" do
    test "integers with maps for parameters and dictionaries" do
      assert {:integer, 42, %{}} == unwrap!(HttpStructuredField.parse_sf_item("42", maps: true))

      assert {:integer, -999_999_999_999_999, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("-999999999999999", maps: true))

      assert {:integer, 5, %{"foo" => {:token, "bar"}}} ==
               unwrap!(HttpStructuredField.parse_sf_item("5; foo=bar", maps: true))
    end

    test "decimals with maps for parameters and dictionaries" do
      assert {:decimal, 4.5, %{}} == unwrap!(HttpStructuredField.parse_sf_item("4.5", maps: true))

      assert {:decimal, -1.5, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("-1.5", maps: true))

      assert {:decimal, 123.456, %{"precision" => {:integer, 3}}} ==
               unwrap!(HttpStructuredField.parse_sf_item("123.456; precision=3", maps: true))
    end

    test "strings with maps for parameters and dictionaries" do
      assert {:string, "hello world", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"hello world"}, maps: true))

      assert {:string, "", %{}} == unwrap!(HttpStructuredField.parse_sf_item(~S{""}, maps: true))

      assert {:string, "Applepie", %{"lang" => {:token, "en"}}} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{"Applepie"; lang=en}, maps: true))
    end

    test "tokens with maps for parameters and dictionaries" do
      assert {:token, "sugar", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("sugar", maps: true))

      assert {:token, "foo123/456", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("foo123/456", maps: true))

      assert {:token, "abc", %{"a" => {:integer, 1}, "b" => {:integer, 2}}} ==
               unwrap!(HttpStructuredField.parse_sf_item("abc;a=1;b=2", maps: true))
    end

    test "byte sequences with maps for parameters and dictionaries" do
      assert {:byte_sequence, "pretend this is binary content.", %{}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(
                   ":cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:",
                   maps: true
                 )
               )

      assert {:byte_sequence, "", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("::", maps: true))

      expected_bytes = Base.decode64!("w4ZibGV0w6ZydGU=")

      assert {:byte_sequence, expected_bytes, %{"encoding" => {:token, "utf8"}}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(":w4ZibGV0w6ZydGU=:; encoding=utf8",
                   maps: true
                 )
               )
    end

    test "booleans with maps for parameters and dictionaries" do
      assert {:boolean, true, %{}} == unwrap!(HttpStructuredField.parse_sf_item("?1", maps: true))

      assert {:boolean, false, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("?0", maps: true))

      assert {:boolean, true, %{"flag" => {:token, "active"}}} ==
               unwrap!(HttpStructuredField.parse_sf_item("?1; flag=active", maps: true))
    end

    test "inner lists with maps for parameters and dictionaries" do
      assert [{:inner_list, [{:string, "foo", %{}}, {:string, "bar", %{}}], %{}}] ==
               unwrap!(HttpStructuredField.parse_sf_list(~S{("foo" "bar")}, maps: true))

      assert [{:inner_list, [], %{}}] ==
               unwrap!(HttpStructuredField.parse_sf_list("()", maps: true))

      assert [
               {:inner_list, [{:integer, 1, %{"a" => {:integer, 2}}}, {:integer, 3, %{}}],
                %{"lvl" => {:integer, 5}}}
             ] ==
               unwrap!(HttpStructuredField.parse_sf_list("(1;a=2 3);lvl=5", maps: true))
    end

    test "lists with maps for parameters and dictionaries" do
      assert [
               {:token, "sugar", %{}},
               {:token, "tea", %{}},
               {:token, "rum", %{}}
             ] == unwrap!(HttpStructuredField.parse_sf_list("sugar, tea, rum", maps: true))

      assert [
               {:token, "abc", %{"a" => {:integer, 1}}}
             ] == unwrap!(HttpStructuredField.parse_sf_list("abc;a=1", maps: true))

      assert [
               {:token, "abc", %{"flag" => {:boolean, true}}},
               {:inner_list, [{:token, "ghi", %{}}, {:token, "l", %{}}], %{"q" => {:string, "9"}}}
             ] ==
               unwrap!(HttpStructuredField.parse_sf_list(~S{abc;flag, (ghi l);q="9"}, maps: true))
    end

    test "dictionaries with maps for parameters and dictionaries" do
      assert %{
               "foo" => {:integer, 1, %{}},
               "bar" => {:integer, 2, %{}}
             } == unwrap!(HttpStructuredField.parse_sf_dictionary("foo=1, bar=2", maps: true))

      assert %{
               "a" => {:boolean, false, %{}},
               "b" => {:boolean, true, %{}}
             } == unwrap!(HttpStructuredField.parse_sf_dictionary("a=?0, b", maps: true))

      assert %{
               "rating" => {:decimal, 1.5, %{}},
               "feelings" => {:inner_list, [{:token, "joy", %{}}, {:token, "sadness", %{}}], %{}}
             } ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary("rating=1.5, feelings=(joy sadness)",
                   maps: true
                 )
               )
    end
  end

  describe "with both unwrap: true and maps: true options" do
    test "integers without type tags and with maps" do
      assert {42, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("42", unwrap: true, maps: true))

      assert {-42, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("-42", unwrap: true, maps: true))

      assert {5, %{"foo" => "bar"}} ==
               unwrap!(HttpStructuredField.parse_sf_item("5; foo=bar", unwrap: true, maps: true))
    end

    test "decimals without type tags and with maps" do
      assert {4.5, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("4.5", unwrap: true, maps: true))

      assert {-1.5, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("-1.5", unwrap: true, maps: true))

      assert {123.456, %{"precision" => 3}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item("123.456; precision=3",
                   unwrap: true,
                   maps: true
                 )
               )
    end

    test "strings without type tags and with maps" do
      assert {"hello world", %{}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(~S{"hello world"}, unwrap: true, maps: true)
               )

      assert {"", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item(~S{""}, unwrap: true, maps: true))

      assert {"Applepie", %{"lang" => "en"}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(~S{"Applepie"; lang=en},
                   unwrap: true,
                   maps: true
                 )
               )
    end

    test "tokens without type tags and with maps" do
      assert {"sugar", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("sugar", unwrap: true, maps: true))

      assert {"foo123/456", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("foo123/456", unwrap: true, maps: true))

      assert {"abc", %{"a" => 1, "b" => 2}} ==
               unwrap!(HttpStructuredField.parse_sf_item("abc;a=1;b=2", unwrap: true, maps: true))
    end

    test "byte sequences without type tags and with maps" do
      assert {"pretend this is binary content.", %{}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(
                   ":cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:",
                   unwrap: true,
                   maps: true
                 )
               )

      assert {"", %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("::", unwrap: true, maps: true))

      expected_bytes = Base.decode64!("w4ZibGV0w6ZydGU=")

      assert {expected_bytes, %{"encoding" => "utf8"}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item(":w4ZibGV0w6ZydGU=:; encoding=utf8",
                   unwrap: true,
                   maps: true
                 )
               )
    end

    test "booleans without type tags and with maps" do
      assert {true, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("?1", unwrap: true, maps: true))

      assert {false, %{}} ==
               unwrap!(HttpStructuredField.parse_sf_item("?0", unwrap: true, maps: true))

      assert {true, %{"flag" => "active"}} ==
               unwrap!(
                 HttpStructuredField.parse_sf_item("?1; flag=active", unwrap: true, maps: true)
               )
    end

    test "inner lists without type tags and with maps" do
      assert [{[{"foo", %{}}, {"bar", %{}}], %{}}] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list(~S{("foo" "bar")}, unwrap: true, maps: true)
               )

      assert [{[], %{}}] ==
               unwrap!(HttpStructuredField.parse_sf_list("()", unwrap: true, maps: true))

      assert [{[{1, %{"a" => 2}}, {3, %{}}], %{"lvl" => 5}}] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list("(1;a=2 3);lvl=5", unwrap: true, maps: true)
               )
    end

    test "lists without type tags and with maps" do
      assert [{"sugar", %{}}, {"tea", %{}}, {"rum", %{}}] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list("sugar, tea, rum", unwrap: true, maps: true)
               )

      assert [{"abc", %{"a" => 1, "b" => 2, "cde_456" => true}}] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list("abc;a=1;b=2; cde_456",
                   unwrap: true,
                   maps: true
                 )
               )

      assert [
               {"abc", %{"a" => 1, "b" => 2, "cde_456" => true}},
               {[{"ghi", %{"jk" => 4}}, {"l", %{}}], %{"q" => "9", "r" => "w"}}
             ] ==
               unwrap!(
                 HttpStructuredField.parse_sf_list(
                   ~S{abc;a=1;b=2; cde_456, (ghi;jk=4 l);q="9";r=w},
                   unwrap: true,
                   maps: true
                 )
               )
    end

    test "dictionaries without type tags and with maps" do
      assert %{
               "foo" => {1, %{}},
               "bar" => {2, %{}}
             } ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary("foo=1, bar=2", unwrap: true, maps: true)
               )

      assert %{
               "a" => {false, %{}},
               "b" => {true, %{}}
             } ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary("a=?0, b", unwrap: true, maps: true)
               )

      assert %{
               "rating" => {1.5, %{}},
               "dup" => {3, %{"b" => 3}},
               "feelings" => {[{"joy", %{}}, {"sadness", %{}}], %{}}
             } ==
               unwrap!(
                 HttpStructuredField.parse_sf_dictionary(
                   "rating=1.5,dup=1,dup=2;a=2,dup=3;b=3, feelings=(joy sadness)",
                   unwrap: true,
                   maps: true
                 )
               )
    end
  end
end
