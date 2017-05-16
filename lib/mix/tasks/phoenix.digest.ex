defmodule Mix.Tasks.Phoenix.Digest do
  use Mix.Task

  @recursive true

  @moduledoc """
  Digests and compress static files.

      mix phoenix.digest
      mix phoenix.digest priv/static -o /www/public

  The first argument is the path where the static files are located. The
  `-o` option indicates the path that will be used to save the digested and
  compressed files.

  If no path is given, it will use `priv/static` as the input and output path.

  The output folder will contain:

    * the original file
    * the file compressed with gzip
    * a file containing the original file name and its digest
    * a compressed file containing the file name and its digest
    * a cache manifest file

  Example of generated files:

    * app.js
    * app.js.gz
    * app-eb0a5b9302e8d32828d8a73f137cc8f0.js
    * app-eb0a5b9302e8d32828d8a73f137cc8f0.js.gz
    * cache_manifest.json
  """

  @doc false
  def run(args) do
    IO.puts :stderr, "mix phoenix.digest is deprecated. Use phx.digest instead."
    Mix.Tasks.Phx.Digest.run(args)
  end
end
