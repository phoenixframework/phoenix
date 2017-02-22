defmodule Mix.Tasks.Phoenix.Digest.Clean do
  use Mix.Task

  @shortdoc "Removes old versions of static assets."
  @recursive true

  @moduledoc """
  Removes old versions of compiled assets.

  By default, it will keep the latest version and
  2 previous versions as well as any digest created
  in the last hour.

      mix phoenix.digest.clean
      mix phoenix.digest.clean -o /www/public
      mix phoenix.digest.clean --age 600 --keep 3

  ## Options

    * `-o, --output` - indicates the path to your compiled
      assets directory. Defaults to `priv/static`.

    * `--age` - specifies a maximum age (in seconds) for assets.
      Files older than age that are not in the last `--keep` versions
      will be removed. Defaults to 3600 (1 hour).

    * `--keep` - specifies how many previous versions of assets to keep.
      Defaults to 2 previous version.

  """
  def run(args) do
    IO.puts :stderr, "mix phoenix.digest.clean is deprecated. Use phx.digest.clean instead."
    Mix.Tasks.Phx.Digest.Clean.run(args)
  end
end
