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
  Digests and compress the static files and save them in the given output path.

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
      Map.put(acc, Path.join(file.relative_path, file.filename),
        Path.join(file.relative_path, file.digested_filename))
    end)

    manifest_content = Poison.Encoder.encode(entries, [])
    File.write!(Path.join(output_path, "manifest.json"), manifest_content)
  end

  defp compiled_file?(file_path) do
    Regex.match?(@digested_file_regex, Path.basename(file_path)) ||
      Path.extname(file_path) == ".gz"
  end

  defp map_file(file_path, input_path) do
    %{absolute_path: file_path,
      relative_path: Path.relative_to(file_path, input_path) |> Path.dirname,
      filename: Path.basename(file_path),
      content: File.read!(file_path)}
  end

  defp compress(file) do
    Map.put(file, :compressed_content, :zlib.gzip(file.content))
  end

  defp digest(file) do
    name = Path.rootname(file.filename)
    extension = Path.extname(file.filename)
    digest = Base.encode16(:erlang.md5(file.content), case: :lower)
    Map.put(file, :digested_filename, "#{name}-#{digest}#{extension}")
  end

  defp write_to_disk(file, output_path) do
    File.mkdir_p!(Path.join(output_path, file.relative_path))
    path = Path.join(output_path, file.relative_path)

    # compressed files
    File.write!(Path.join(path, file.digested_filename <> ".gz"), file.compressed_content)
    File.write!(Path.join(path, file.filename <> ".gz"), file.compressed_content)
    # uncompressed files
    File.write!(Path.join(path, file.digested_filename), file.content)
    File.write!(Path.join(path, file.filename), file.content)

    file
  end
end
