defmodule Phoenix.Digester do
  @digested_file_regex ~r/(-[a-fA-F\d]{32})/
  @manifest_version 1
  @empty_manifest %{
    "version" => 1,
    "digests" => %{},
    "latest" => %{}
  }

  defp now() do
    :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
  end

  @moduledoc false

  @doc """
  Digests and compresses the static files in the given `input_path`
  and saves them in the given `output_path`.
  """
  @spec compile(String.t(), String.t()) :: :ok | {:error, :invalid_path}
  def compile(input_path, output_path) do
    if File.exists?(input_path) do
      unless File.exists?(output_path), do: File.mkdir_p!(output_path)

      {digested_files, manifest} =
        input_path
        |> filter_files()
        |> Enum.map(&digest/1)
        |> generate_manifest()
        |> add_digested_content()

      digests = load_compile_digests(output_path)
      save_manifest(digested_files, manifest, digests, output_path)

      Enum.each(digested_files, &write_to_disk(&1, output_path))
    else
      {:error, :invalid_path}
    end
  end

  defp filter_files(input_path) do
    input_path
    |> Path.join("**")
    |> Path.wildcard()
    |> Enum.filter(&(not (File.dir?(&1) or compiled_file?(&1))))
    |> Enum.map(&map_file(&1, input_path))
  end

  defp filter_digested_files(output_path) do
    output_path
    |> Path.join("**")
    |> Path.wildcard()
    |> Enum.filter(&uncompressed_digested_file?/1)
    |> Enum.map(&map_digested_file(&1, output_path))
  end

  defp load_compile_digests(output_path) do
    manifest = load_manifest(output_path)
    manifest["digests"]
  end

  defp load_manifest(output_path) do
    manifest_path = Path.join(output_path, "cache_manifest.json")

    if File.exists?(manifest_path) do
      manifest_path
      |> File.read!()
      |> Phoenix.json_library().decode!()
      |> migrate_manifest(output_path)
    else
      @empty_manifest
    end
  end

  defp migrate_manifest(%{"version" => 1} = manifest, _output_path), do: manifest

  defp migrate_manifest(latest, output_path) do
    digests =
      output_path
      |> filter_digested_files
      |> generate_new_digests()

    @empty_manifest
    |> Map.put("digests", digests)
    |> Map.put("latest", latest)
  end

  defp generate_manifest(files) do
    {files,
     Map.new(
       files,
       &{
         manifest_join(&1.relative_path, &1.filename),
         manifest_join(&1.relative_path, &1.digested_filename)
       }
     )}
  end

  defp add_digested_content({files, manifest}) do
    {Enum.map(files, fn file ->
       Map.put(file, :digested_content, digested_contents(file, manifest))
     end), manifest}
  end

  defp save_manifest(files, latest, old_digests, output_path) do
    old_digests_that_still_exist =
      old_digests
      |> Enum.filter(fn {file, _} -> File.exists?(Path.join(output_path, file)) end)
      |> Map.new()

    new_digests = generate_new_digests(files)

    digests = Map.merge(old_digests_that_still_exist, new_digests)

    save_manifest(
      %{"latest" => latest, "version" => @manifest_version, "digests" => digests},
      output_path
    )
  end

  defp save_manifest(%{"latest" => _, "version" => _, "digests" => _} = manifest, output_path) do
    manifest_content = Phoenix.json_library().encode!(manifest)
    File.write!(Path.join(output_path, "cache_manifest.json"), manifest_content)
  end

  defp generate_new_digests(files) do
    Map.new(
      files,
      &{
        manifest_join(&1.relative_path, &1.digested_filename),
        build_digest(&1)
      }
    )
  end

  defp build_digest(file) do
    %{
      logical_path: manifest_join(file.relative_path, file.filename),
      mtime: now(),
      size: file.size,
      digest: file.digest,
      sha512: Base.encode64(:crypto.hash(:sha512, file.digested_content))
    }
  end

  defp manifest_join(".", filename), do: filename
  defp manifest_join(path, filename), do: Path.join(path, filename)

  defp compiled_file?(file_path) do
    Regex.match?(@digested_file_regex, Path.basename(file_path)) ||
      Path.extname(file_path) == ".gz" ||
      Path.basename(file_path) == "cache_manifest.json"
  end

  defp uncompressed_digested_file?(file_path) do
    Regex.match?(@digested_file_regex, Path.basename(file_path)) ||
      !Path.extname(file_path) == ".gz"
  end

  defp map_file(file_path, input_path) do
    {:ok, stats} = File.stat(file_path)

    %{
      absolute_path: file_path,
      relative_path: Path.relative_to(file_path, input_path) |> Path.dirname(),
      filename: Path.basename(file_path),
      size: stats.size,
      content: File.read!(file_path)
    }
  end

  defp map_digested_file(file_path, output_path) do
    {:ok, stats} = File.stat(file_path)
    digested_filename = Path.basename(file_path)
    [digest, _] = Regex.run(@digested_file_regex, digested_filename)
    digest = String.trim_leading(digest, "-")

    %{
      absolute_path: file_path,
      relative_path: Path.relative_to(file_path, output_path) |> Path.dirname(),
      digested_filename: digested_filename,
      filename: String.replace(digested_filename, @digested_file_regex, ""),
      digest: digest,
      size: stats.size,
      content: File.read!(file_path)
    }
  end

  defp digest(file) do
    name = Path.rootname(file.filename)
    extension = Path.extname(file.filename)
    digest = Base.encode16(:erlang.md5(file.content), case: :lower)

    Map.merge(file, %{
      digested_filename: "#{name}-#{digest}#{extension}",
      digest: digest
    })
  end

  defp write_to_disk(file, output_path) do
    path = Path.join(output_path, file.relative_path)
    File.mkdir_p!(path)

    # compressed files
    if compress_file?(file) do
      File.write!(
        Path.join(path, file.digested_filename <> ".gz"),
        :zlib.gzip(file.digested_content)
      )

      File.write!(Path.join(path, file.filename <> ".gz"), :zlib.gzip(file.content))
    end

    # uncompressed files
    File.write!(Path.join(path, file.digested_filename), file.digested_content)
    File.write!(Path.join(path, file.filename), file.content)

    file
  end

  defp compress_file?(file) do
    Path.extname(file.filename) in Application.get_env(:phoenix, :gzippable_exts)
  end

  defp digested_contents(file, manifest) do
    case Path.extname(file.filename) do
      ".css" -> digest_stylesheet_asset_references(file, manifest)
      ".js" -> digest_javascript_asset_references(file, manifest)
      ".map" -> digest_javascript_map_asset_references(file, manifest)
      _ -> file.content
    end
  end

  @stylesheet_url_regex ~r{(url\(\s*)(\S+?)(\s*\))}
  @quoted_text_regex ~r{\A(['"])(.+)\1\z}

  defp digest_stylesheet_asset_references(file, manifest) do
    Regex.replace(@stylesheet_url_regex, file.content, fn _, open, url, close ->
      case Regex.run(@quoted_text_regex, url) do
        [_, quote_symbol, url] ->
          open <> quote_symbol <> digested_url(url, file, manifest, true) <> quote_symbol <> close

        nil ->
          open <> digested_url(url, file, manifest, true) <> close
      end
    end)
  end

  @javascript_source_map_regex ~r{(//#\s*sourceMappingURL=\s*)(\S+)}

  defp digest_javascript_asset_references(file, manifest) do
    Regex.replace(@javascript_source_map_regex, file.content, fn _, source_map_text, url ->
      source_map_text <> digested_url(url, file, manifest, false)
    end)
  end

  @javascript_map_file_regex ~r{(['"]file['"]:['"])([^,"']+)(['"])}

  defp digest_javascript_map_asset_references(file, manifest) do
    Regex.replace(@javascript_map_file_regex, file.content, fn _, open_text, url, close_text ->
      open_text <> digested_url(url, file, manifest, false) <> close_text
    end)
  end

  defp digested_url("/" <> relative_path, _file, manifest, with_vsn?) do
    case Map.fetch(manifest, relative_path) do
      {:ok, digested_path} -> relative_digested_path(digested_path, with_vsn?)
      :error -> "/" <> relative_path
    end
  end

  defp digested_url(url, file, manifest, with_vsn?) do
    case URI.parse(url) do
      %URI{scheme: nil, host: nil} ->
        manifest_path =
          file.relative_path
          |> Path.join(url)
          |> Path.expand()
          |> Path.relative_to_cwd()

        case Map.fetch(manifest, manifest_path) do
          {:ok, digested_path} ->
            absolute_digested_url(url, digested_path, with_vsn?)

          :error ->
            url
        end

      _ ->
        url
    end
  end

  defp relative_digested_path(digested_path, true),
    do: relative_digested_path(digested_path) <> "?vsn=d"

  defp relative_digested_path(digested_path, false), do: relative_digested_path(digested_path)
  defp relative_digested_path(digested_path), do: "/" <> digested_path

  defp absolute_digested_url(url, digested_path, true) do
    absolute_digested_url(url, digested_path) <> "?vsn=d"
  end

  defp absolute_digested_url(url, digested_path, false) do
    absolute_digested_url(url, digested_path)
  end

  defp absolute_digested_url(url, digested_path) do
    url
    |> Path.dirname()
    |> Path.join(Path.basename(digested_path))
  end

  @doc """
  Deletes compiled/compressed asset files that are no longer in use based on
  the specified criteria.

  ## Arguments

    * `path` - The path where the compiled/compressed files are saved
    * `age` - The max age of assets to keep in seconds
    * `keep` - The number of old versions to keep

  """
  @spec clean(String.t(), integer, integer, integer) :: :ok | {:error, :invalid_path}
  def clean(path, age, keep, now \\ now()) do
    if File.exists?(path) do
      manifest = load_manifest(path)
      files = files_to_clean(manifest, now - age, keep)
      remove_files(files, path)
      remove_files_from_manifest(manifest, files, path)
      :ok
    else
      {:error, :invalid_path}
    end
  end

  defp files_to_clean(manifest, max_age, keep) do
    latest = Map.values(manifest["latest"])
    digests = Map.drop(manifest["digests"], latest)

    for {_, versions} <- group_by_logical_path(digests),
        file <- versions_to_clean(versions, max_age, keep),
        do: file
  end

  defp versions_to_clean(versions, max_age, keep) do
    versions
    |> Enum.map(fn {path, attrs} -> Map.put(attrs, "path", path) end)
    |> Enum.sort_by(& &1["mtime"], &>/2)
    |> Enum.with_index(1)
    |> Enum.filter(fn {version, index} ->
      max_age > version["mtime"] || index > keep
    end)
    |> Enum.map(fn {version, _index} -> version["path"] end)
  end

  defp group_by_logical_path(digests) do
    Enum.group_by(digests, fn {_, attrs} -> attrs["logical_path"] end)
  end

  defp remove_files(files, output_path) do
    for file <- files do
      output_path
      |> Path.join(file)
      |> File.rm()

      output_path
      |> Path.join("#{file}.gz")
      |> File.rm()
    end
  end

  defp remove_files_from_manifest(manifest, files, output_path) do
    manifest
    |> Map.update!("digests", &Map.drop(&1, files))
    |> save_manifest(output_path)
  end
end
