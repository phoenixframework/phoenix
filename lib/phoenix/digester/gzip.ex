defmodule Phoenix.Digester.Gzip do
  @behaviour Phoenix.Digester.Compressor
  def compress_file(file_path, content) do
    if Path.extname(file_path) in Application.fetch_env!(:phoenix, :gzippable_exts) do
      {:ok, :zlib.gzip(content)}
    else
      :error
    end
  end

  def file_extensions do
    [".gz"]
  end
end
