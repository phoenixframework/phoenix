defmodule Phoenix.Digester.Gzip do
  @behaviour Phoenix.Digester.Compressor
  def compress(content) do
    :zlib.gzip(content)
  end

  def file_extension do
    ".gz"
  end

  def compress_file?(file_path, _content, _digested_content) do
    Path.extname(file_path) in Application.fetch_env!(:phoenix, :gzippable_exts)
  end
end
