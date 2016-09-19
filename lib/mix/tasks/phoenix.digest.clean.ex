defmodule Mix.Tasks.Phoenix.Digest.Clean do
  use Mix.Task
  @default_output_path "priv/static"
  @default_age 3600
  @default_keep 2

  @shortdoc "Removes old versions of static assets."
  @recursive true

  @moduledoc """
  Removes old versions of compiled assets. By default, it will keep the latest version
  and 2 previous versions, and any created in the last hour.

      mix phoenix.digest.clean
      mix phoenix.digest.clean -o /www/public
      mix phoenix.digest.clean --age 600 --keep 3

  * `-o, --output` indicates the path to your compiled assets directory, by default `priv/static`.
  * `--age` allows you to specify a maximum age (in minutes) for assets, and all
  files old than that will be removed. It defaults to 3600 (1 hour).
  * `--keep` allows you to specify how many previous versions of assets to keep.
  It defaults to 2 previous version.
  """

  def run(args) do
    switches = [output: :string, age: :integer, keep: :integer]
    {opts, _, _} = OptionParser.parse(args, switches: switches, aliases: [o: :output])
    output_path = opts[:output] || @default_output_path
    age = opts[:age] || @default_age
    keep = opts[:keep] || @default_keep

    {:ok, _} = Application.ensure_all_started(:phoenix)

    case Phoenix.DigestCleaner.clean(output_path, age, keep) do
      :ok ->
        Mix.shell.info [:green, "Clean complete for #{inspect output_path}"]
      {:error, :invalid_path} ->
        Mix.shell.error "The output path #{inspect output_path} does not exist"
    end
  end
end
