defmodule Mix.Tasks.Phoenix.Digest do
  use Mix.Task
  @default_input_path "priv/static"

  @shortdoc "Digests and compress static files"

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
    * a compressed file with gzip
    * a file containing the original file name and its digest
    * a compressed file containing the file name and its digest
    * a manifest file

  Example of generated files:

    * application.js.erb
    * application.js.erb.gz
    * application.js-eb0a5b9302e8d32828d8a73f137cc8f0.erb
    * application.js-eb0a5b9302e8d32828d8a73f137cc8f0.erb.gz
    * manifest.json
  """

  def run(args) do
    {opts, args, _} = OptionParser.parse(args, aliases: [o: :output])
    input_path  = List.first(args) || @default_input_path
    output_path = opts[:output] || input_path

    case Phoenix.Digester.compile(input_path, output_path) do
      :ok ->
        # We need to call build structure so everything we have
        # generated into priv is copied to _build in case we have
        # build_embedded set to true. In case if it not true,
        # build structure is mostly a no-op, so we are fine.
        Mix.Project.build_structure()
        Mix.shell.info [:green, "Check your digested files at '#{output_path}'."]
      {:error, :invalid_path} ->
        Mix.raise "The input path '#{input_path}' does not exist."
    end
  end
end
