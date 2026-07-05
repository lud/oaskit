#!/usr/bin/env elixir
Mix.install([:req])

defmodule UpdateRedoc do
  @moduledoc """
  Pins the Redoc CDN bundle used by `Oaskit.SpecController` to the latest
  published version and refreshes its Subresource Integrity (SRI) hash.

  It fetches the latest `redoc` version from the npm registry, downloads the
  exact bundle served by the CDN for that version, computes its `sha384` SRI
  hash, and rewrites the `@redoc_version` and `@redoc_sri` module attributes in
  the source file. It then compiles the project and runs the test suite so a
  bad bundle or a broken pin fails loudly.

  Run it locally to update the library:

      ./tools/update-redoc.exs

  The weekly CI workflow runs the same script and then fails if it produced any
  change, signalling that a new Redoc version needs to be committed.
  """

  @root Path.expand("..", __DIR__)
  @source Path.join(@root, "lib/oaskit/spec_controller.ex")

  @npm_latest "https://registry.npmjs.org/redoc/latest"
  @cdn_bundle "https://cdn.redoc.ly/redoc/v~s/bundles/redoc.standalone.js"

  def run do
    version = fetch_latest_version()
    url = bundle_url(version)
    bundle = fetch_bundle(url)
    sri = sri_hash(bundle)

    log("latest redoc version: #{version}")
    log("bundle: #{url} (#{byte_size(bundle)} bytes)")
    log("sri: #{sri}")

    update_source!(version, sri)

    log("updated #{Path.relative_to(@source, @root)}")

    mix!(["compile", "--force", "--warnings-as-errors"])
    mix!(["test"])

    log("done")
  end

  defp fetch_latest_version do
    case Req.get!(@npm_latest) do
      %{status: 200, body: %{"version" => version}} when is_binary(version) ->
        validate_version!(version)

      other ->
        fail("unexpected response from npm registry: #{inspect(other.status)}")
    end
  end

  defp validate_version!(version) do
    if version =~ ~r/^\d+\.\d+\.\d+/ do
      version
    else
      fail("npm returned an unexpected version string: #{inspect(version)}")
    end
  end

  defp bundle_url(version) do
    :io_lib.format(@cdn_bundle, [version]) |> IO.iodata_to_binary()
  end

  defp fetch_bundle(url) do
    # `decode_body: false` keeps the raw bytes so the SRI hash matches exactly
    # what the browser will download.
    case Req.get!(url, decode_body: false) do
      %{status: 200, body: body} when byte_size(body) > 0 ->
        body

      other ->
        fail("could not download redoc bundle from #{url} (status #{other.status})")
    end
  end

  defp sri_hash(bundle) do
    "sha384-" <> Base.encode64(:crypto.hash(:sha384, bundle))
  end

  defp update_source!(version, sri) do
    source = File.read!(@source)

    source
    |> replace_attr!(:redoc_version, version)
    |> replace_attr!(:redoc_sri, sri)
    |> then(&File.write!(@source, &1))
  end

  defp replace_attr!(source, attr, value) do
    pattern = ~r/@#{attr} "[^"]*"/

    unless Regex.match?(pattern, source) do
      fail("could not find `@#{attr}` attribute in #{@source}")
    end

    # Replace with a function so the value (which contains SRI base64 chars like
    # `+` and `/`) is inserted verbatim, without replacement-string escaping.
    Regex.replace(pattern, source, fn _ -> ~s(@#{attr} "#{value}") end, global: false)
  end

  defp mix!(args) do
    log("mix #{Enum.join(args, " ")}")

    {_, status} =
      System.cmd("mix", args,
        cd: @root,
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if status != 0 do
      fail("`mix #{Enum.join(args, " ")}` exited with status #{status}")
    end
  end

  defp log(message) do
    IO.puts([IO.ANSI.cyan(), "[update-redoc] ", IO.ANSI.reset(), message])
  end

  defp fail(message) do
    IO.puts(:stderr, [IO.ANSI.red(), "[update-redoc] ", message, IO.ANSI.reset()])
    System.halt(1)
  end
end

UpdateRedoc.run()
