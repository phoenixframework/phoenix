defmodule Phoenix.Digester.Compressor do
  @callback compress(binary()) :: binary()
  @callback file_extensions() :: nonempty_list(String.t())
  @callback compress_file?(Path.t(), binary(), binary()) :: bool()
end
