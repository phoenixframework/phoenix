defmodule Phoenix.Digester.Compressor do
  @callback compress_file(Path.t(), binary()) :: {:ok, binary()} | :error
  @callback file_extensions() :: nonempty_list(String.t())
end
