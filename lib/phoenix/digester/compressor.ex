defmodule Phoenix.Digester.Compressor do
  @moduledoc ~S"""
  Defines the `Phoenix.Digester.Compressor` behaviour for
  implementing static file compressors.

  A custom compressor expects 2 functions to be implemented.

  By default, Phoenix uses only `Phoenix.Digester.Gzip` to compress
  static files, but additional compressors can be defined and added
  to the digest process.

  ## Example

  If you wanted to compress files using an external brotli compression
  library, you could define a new module implementing the behaviour and add the
  module to the list of configured Phoenix static compressors.

      defmodule MyApp.BrotliCompressor do
        @behaviour Phoenix.Digester.Compressor

        def compress_file(file_path, content) do
          valid_extension = Path.extname(file_path) in Application.fetch_env!(:phoenix, :gzippable_exts)
          compressed_content = :brotli.encode(content)

          if valid_extension && byte_size(compressed_content) < byte_size(content) do
            {:ok, compressed_content}
          else
            :error
          end
        end

        def file_extensions do
          [".br"]
        end
      end

      # config/config.exs
      config :phoenix,
        static_compressors: [Phoenix.Digester.Gzip, MyApp.BrotliCompressor],
        # ...
  """
  @callback compress_file(Path.t(), binary()) :: {:ok, binary()} | :error
  @callback file_extensions() :: nonempty_list(String.t())
end
