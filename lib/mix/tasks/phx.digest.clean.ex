defmodule Mix.Tasks.Phx.Digest.Clean do
  use Mix.Task
  @default_output_path "priv/static"
  @default_age 3600
  @default_keep 2

  @shortdoc "Removes old versions of static assets."
  @recursive true

  @moduledoc """
  Removes old versions of compiled assets.

  By default, it will keep the latest version and
  2 previous versions as well as any digest created
  in the last hour.

      $ mix phx.digest.clean
      $ mix phx.digest.clean -o /www/public
      $ mix phx.digest.clean --age 600 --keep 3
      $ mix phx.digest.clean --all

  ## Options

    * `-o, --output` - indicates the path to your compiled
      assets directory. Defaults to `priv/static`

    * `--age` - specifies a maximum age (in seconds) for assets.
      Files older than age that are not in the last `--keep` versions
      will be removed. Defaults to 3600 (1 hour)

    * `--keep` - specifies how many previous versions of assets to keep.
      Defaults to 2 previous versions

    * `--all` - specifies that all compiled assets (including the manifest)
      will be removed. Note this overrides the age and keep switches.
  """

  @doc false
  def run(args) do
    switches = [output: :string, age: :integer, keep: :integer, all: :boolean]
    {opts, _, _} = OptionParser.parse(args, switches: switches, aliases: [o: :output])
    output_path = opts[:output] || @default_output_path
    age = opts[:age] || @default_age
    keep = opts[:keep] || @default_keep
    all? = opts[:all] || false

    {:ok, _} = Application.ensure_all_started(:phoenix)

    result =
      if all?,
        do: Phoenix.Digester.clean_all(output_path),
        else: Phoenix.Digester.clean(output_path, age, keep)

    case result do
      :ok ->
        # We need to call build structure so everything we have cleaned from
        # priv is removed from _build in case we have build_embedded set to
        # true. In case it's not true, build structure is mostly a no-op, so we
        # are fine.
        Mix.Project.build_structure()
        Mix.shell().info [:green, "Clean complete for #{inspect output_path}"]
      {:error, :invalid_path} ->
        Mix.shell().error "The output path #{inspect output_path} does not exist"
    end
  end
end
