#!/usr/bin/env elixir
Mix.install([:req])

defmodule UpdateRedoc do
  @moduledoc """
  Pins each Redoc major version used by `Oaskit.SpecController` to its latest
  published release and refreshes its Subresource Integrity (SRI) hash.

  For each pinned major version, it finds the latest stable `redoc` release of
  that major in the npm registry, downloads the exact bundle served by the CDN
  for that version, checks that it is byte-identical to the bundle in the npm
  tarball (itself checked against the registry integrity hash), computes its
  `sha384` SRI hash, and rewrites the matching
  `@*_version` and `@*_sri` module attributes in the source file. It then
  compiles the project and runs the test suite so a bad bundle or a broken pin
  fails loudly. It fails before changing anything when npm publishes a major
  version that has no pin yet.

  Run it locally to update the library:

      ./tools/update-redoc.exs

  The weekly CI workflow runs the same script and then fails if it produced any
  change, signalling that a new Redoc version needs to be committed.
  """

  @root Path.expand("..", __DIR__)
  @source Path.join(@root, "lib/oaskit/spec_controller.ex")

  @npm_package "https://registry.npmjs.org/redoc"
  @cdn_bundle "https://cdn.redoc.ly/redoc/v~s/bundles/redoc.standalone.js"

  # Major version => attribute prefix in the source file
  @pins %{2 => "redoc", 3 => "redoc3"}

  def run do
    releases = fetch_stable_releases()

    check_unpinned_major!(releases)

    Enum.each(@pins, fn {major, prefix} ->
      {version, dist} = latest_of_major!(releases, major)
      version = Version.to_string(version)
      url = bundle_url(version)
      bundle = fetch_bundle(url)
      verify_against_npm!(bundle, dist)
      sri = sri_hash(bundle)

      log("latest redoc #{major}.x version: #{version}")
      log("bundle: #{url} (#{byte_size(bundle)} bytes, matches npm tarball)")
      log("sri: #{sri}")

      update_source!(prefix, version, sri)
    end)

    log("updated #{Path.relative_to(@source, @root)}")

    mix!(["compile", "--force", "--warnings-as-errors"])
    mix!(["test"])

    log("done")
  end

  defp fetch_stable_releases do
    case Req.get!(@npm_package) do
      %{status: 200, body: %{"versions" => versions}} when is_map(versions) ->
        Enum.flat_map(versions, fn {vsn, meta} ->
          case Version.parse(vsn) do
            {:ok, %Version{pre: [], build: nil} = version} -> [{version, meta["dist"]}]
            _ -> []
          end
        end)

      other ->
        fail("unexpected response from npm registry: #{inspect(other.status)}")
    end
  end

  defp latest_of_major!(releases, major) do
    case Enum.filter(releases, fn {version, _} -> version.major == major end) do
      [] -> fail("npm has no stable redoc #{major}.x version")
      list -> Enum.max_by(list, &elem(&1, 0), Version)
    end
  end

  defp check_unpinned_major!(releases) do
    {latest, _} = Enum.max_by(releases, &elem(&1, 0), Version)

    if latest.major > Enum.max(Map.keys(@pins)) do
      fail("redoc #{latest.major}.x is published but has no pin in #{@source}")
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

  # The CDN bundle must be byte-identical to the one in the npm tarball, and the
  # tarball must match the integrity hash published by the registry.
  defp verify_against_npm!(bundle, %{"tarball" => tarball_url, "integrity" => integrity}) do
    tarball =
      case Req.get!(tarball_url, decode_body: false, raw: true) do
        %{status: 200, body: body} -> body
        other -> fail("could not download #{tarball_url} (status #{other.status})")
      end

    if integrity != "sha512-" <> Base.encode64(:crypto.hash(:sha512, tarball)) do
      fail("#{tarball_url} does not match the npm integrity #{integrity}")
    end

    if bundle != extract_bundle!(tarball, tarball_url) do
      fail("CDN bundle differs from the bundle in #{tarball_url}")
    end
  end

  defp verify_against_npm!(_bundle, dist) do
    fail("npm dist metadata lacks tarball or integrity: #{inspect(dist)}")
  end

  defp extract_bundle!(tarball, tarball_url) do
    file = ~c"package/bundles/redoc.standalone.js"

    case :erl_tar.extract({:binary, tarball}, [:compressed, :memory, files: [file]]) do
      {:ok, [{^file, bundle}]} -> bundle
      other -> fail("could not extract #{file} from #{tarball_url}: #{inspect(other)}")
    end
  end

  defp sri_hash(bundle) do
    "sha384-" <> Base.encode64(:crypto.hash(:sha384, bundle))
  end

  defp update_source!(prefix, version, sri) do
    source = File.read!(@source)

    source
    |> replace_attr!("#{prefix}_version", version)
    |> replace_attr!("#{prefix}_sri", sri)
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
