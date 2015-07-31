defmodule Phoenix.Digester do
  @digested_file_regex ~r/(-[a-fA-F\d]{32})/

  @moduledoc """
  Digests and compress static files.

  For each file under the given input path, Phoenix will generate a digest
  and also compress in `.gz` format. The filename and its digest will be
  used to generate the manifest file. It also avoid duplications checking
  for already digested files.
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

      input_path
      |> filter_files
      |> do_compile(output_path)
      |> generate_manifest(output_path)
      :ok
    else
      {:error, :invalid_path}
    end
  end

  defp filter_files(input_path) do
    input_path
    |> Path.join("**")
    |> Path.wildcard
    |> Enum.filter(&(!File.dir?(&1) && !compiled_file?(&1)))
    |> Enum.map(&(map_file(&1, input_path)))
  end

  defp do_compile(files, output_path) do
    Enum.map(files, fn (file) ->
      file
      |> digest
      |> compress
      |> write_to_disk(output_path)
    end)
  end

  defp generate_manifest(files, output_path) do
    entries = Enum.reduce(files, %{}, fn (file, acc) ->
      Map.put(acc, manifest_join(file.relative_path, file.filename),
                   manifest_join(file.relative_path, file.digested_filename))
    end)

    manifest_content = Poison.encode!(entries, [])
    File.write!(Path.join(output_path, "manifest.json"), manifest_content)
  end

  defp manifest_join(".", filename),  do: filename
  defp manifest_join(path, filename), do: Path.join(path, filename)

  defp compiled_file?(file_path) do
    Regex.match?(@digested_file_regex, Path.basename(file_path)) ||
      Path.extname(file_path) == ".gz" ||
      Path.basename(file_path) == "manifest.json"
  end

  defp map_file(file_path, input_path) do
    %{absolute_path: file_path,
      relative_path: Path.relative_to(file_path, input_path) |> Path.dirname,
      filename: Path.basename(file_path),
      content: File.read!(file_path),
      compressed_content: nil}
  end

  defp compress(file) do
    if Path.extname(file.filename) in Application.get_env(:phoenix, :gzippable_exts) do
      Map.put(file, :compressed_content, :zlib.gzip(file.content))
    else
      file
    end
  end

  defp digest(file) do
    name = Path.rootname(file.filename)
    extension = Path.extname(file.filename)
    digest = Base.encode16(:erlang.md5(file.content), case: :lower)
    Map.put(file, :digested_filename, "#{name}-#{digest}#{extension}")
  end

  defp write_to_disk(file, output_path) do
    path = Path.join(output_path, file.relative_path)
    File.mkdir_p!(path)

    # compressed files
    if file.compressed_content do
      File.write!(Path.join(path, file.digested_filename <> ".gz"), file.compressed_content)
      File.write!(Path.join(path, file.filename <> ".gz"), file.compressed_content)
    end

    # uncompressed files
    File.write!(Path.join(path, file.digested_filename), file.content)
    File.write!(Path.join(path, file.filename), file.content)

    file
  end
end
