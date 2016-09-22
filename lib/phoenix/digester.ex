defmodule Phoenix.Digester do
  @digested_file_regex ~r/(-[a-fA-F\d]{32})/
  @manifest_version 1

  @moduledoc """
  Digests and compresses static files.

  For each file under the given input path, Phoenix will generate a digest
  and also compress in `.gz` format. The filename and its digest will be
  used to generate the manifest file. It also avoids duplication, checking
  for already digested files.

  For stylesheet files found under the given path, Phoenix will replace
  asset references with the digested paths, as long as the asset exists
  in the generated manifest.
  """

  @doc """
  Digests and compresses the static files and saves them in the given output path.

    * `input_path` - The path where the assets are located
    * `output_path` - The path where the compiled/compressed files will be saved
  """
  @spec compile(String.t, String.t) :: :ok | {:error, :invalid_path}
  def compile(input_path, output_path) do
    if File.exists?(input_path) do
      unless File.exists?(output_path), do: File.mkdir_p!(output_path)

      digested_files =
        input_path
        |> filter_files
        |> Enum.map(&digest/1)

      digests = load_digests(output_path)
      manifest = generate_manifest(digested_files, digests, output_path)

      Enum.each(digested_files, &(write_to_disk(&1, manifest, output_path)))
    else
      {:error, :invalid_path}
    end
  end

  defp filter_files(input_path) do
    input_path
    |> Path.join("**")
    |> Path.wildcard
    |> Enum.filter(&not(File.dir?(&1) or compiled_file?(&1)))
    |> Enum.map(&(map_file(&1, input_path)))
  end

  defp filter_digested_files(output_path) do
    output_path
    |> Path.join("**")
    |> Path.wildcard
    |> Enum.filter(&uncompressed_digested_file?/1)
    |> Enum.map(&(map_digested_file(&1, output_path)))
  end

  defp load_digests(output_path) do
    manifest_path = Path.join(output_path, "manifest.json")
    if File.exists?(manifest_path) do
      manifest_path
      |> File.read!
      |> Poison.decode!
      |> get_digest(output_path)
    else
      %{}
    end
  end

  defp get_digest(manifest = %{version: 1}, _output_path) do
    Access.get(manifest, "digests")
  end

  defp get_digest(_manifest, output_path) do
    output_path
    |> filter_digested_files
    |> generate_new_digests
  end

  defp generate_manifest(files, old_digests, output_path) do
    latest = Map.new(files, &({
       manifest_join(&1.relative_path, &1.filename),
       manifest_join(&1.relative_path, &1.digested_filename)
    }))

    digests =
      files
      |> generate_new_digests
      |> Map.merge(old_digests)

    manifest_content = Poison.encode!(%{latest: latest, version: @manifest_version, digests: digests}, [])
    File.write!(Path.join(output_path, "manifest.json"), manifest_content)

    latest
  end

  defp generate_new_digests(files) do
    Map.new(files, &({
       manifest_join(&1.relative_path, &1.digested_filename),
       build_digest(&1)
     }))
  end

  defp build_digest(file) do
    %{
      logical_path: manifest_join(file.relative_path, file.filename),
      mtime: :calendar.datetime_to_gregorian_seconds(:calendar.universal_time),
      size: file.size,
      digest: file.digest,
    }
  end

  defp manifest_join(".", filename),  do: filename
  defp manifest_join(path, filename), do: Path.join(path, filename)

  defp compiled_file?(file_path) do
    Regex.match?(@digested_file_regex, Path.basename(file_path)) ||
      Path.extname(file_path) == ".gz" ||
      Path.basename(file_path) == "manifest.json"
  end

  defp uncompressed_digested_file?(file_path) do
    Regex.match?(@digested_file_regex, Path.basename(file_path)) ||
      !Path.extname(file_path) == ".gz"
  end

  defp map_file(file_path, input_path) do
    {:ok, stats} = File.stat(file_path)
    %{absolute_path: file_path,
      relative_path: Path.relative_to(file_path, input_path) |> Path.dirname(),
      filename: Path.basename(file_path),
      size: stats.size,
      content: File.read!(file_path)}
  end

  defp map_digested_file(file_path, output_path) do
    {:ok, stats} = File.stat(file_path)
    digested_filename = Path.basename(file_path)
    [digest,_] = Regex.run(@digested_file_regex, digested_filename)
    digest = String.trim_leading(digest, "-")

    %{absolute_path: file_path,
      relative_path: Path.relative_to(file_path, output_path) |> Path.dirname(),
      digested_filename: digested_filename,
      filename: String.replace(digested_filename, @digested_file_regex, ""),
      digest: digest,
      size: stats.size,
      content: File.read!(file_path)}
  end

  defp digest(file) do
    name = Path.rootname(file.filename)
    extension = Path.extname(file.filename)
    digest = Base.encode16(:erlang.md5(file.content), case: :lower)
    Map.merge(file, %{
      digested_filename: "#{name}-#{digest}#{extension}",
      digest: digest,
    })
  end

  defp write_to_disk(file, manifest, output_path) do
    path = Path.join(output_path, file.relative_path)
    File.mkdir_p!(path)

    digested_file_contents = digested_contents(file, manifest)

    # compressed files
    if compress_file?(file) do
      File.write!(Path.join(path, file.digested_filename <> ".gz"), :zlib.gzip(digested_file_contents))
      File.write!(Path.join(path, file.filename <> ".gz"), :zlib.gzip(file.content))
    end

    # uncompressed files
    File.write!(Path.join(path, file.digested_filename), digested_file_contents)
    File.write!(Path.join(path, file.filename), file.content)

    file
  end

  defp compress_file?(file) do
    Path.extname(file.filename) in Application.get_env(:phoenix, :gzippable_exts)
  end

  defp digested_contents(file, manifest) do
    if Path.extname(file.filename) == ".css" do
      digest_asset_references(file, manifest)
    else
      file.content
    end
  end

  @stylesheet_url_regex ~r{(url\(\s*)(\S+?)(\s*\))}
  @quoted_text_regex ~r{\A(['"])(.+)\1\z}

  defp digest_asset_references(file, manifest) do
    Regex.replace(@stylesheet_url_regex, file.content, fn _, open, url, close ->
      case Regex.run(@quoted_text_regex, url) do
        [_, quote_symbol, url] ->
          open <> quote_symbol <> digested_url(url, file, manifest) <> quote_symbol <> close
        nil ->
          open <> digested_url(url, file, manifest) <> close
      end
    end)
  end

  defp digested_url("/" <> relative_path, _file, manifest) do
    case Map.fetch(manifest, relative_path) do
      {:ok, digested_path} -> "/" <> digested_path <> "?vsn=d"
      :error -> "/" <> relative_path
    end
  end

  defp digested_url(url, file, manifest) do
    case URI.parse(url) do
      %URI{scheme: nil, host: nil} ->
        manifest_path =
          file.relative_path
          |> Path.join(url)
          |> Path.expand()
          |> Path.relative_to_cwd()

        case Map.fetch(manifest, manifest_path) do
          {:ok, digested_path} ->
            url
            |> Path.dirname()
            |> Path.join(Path.basename(digested_path))
            |> Kernel.<>("?vsn=d")
          :error -> url
        end
      _ -> url
    end
  end
end
