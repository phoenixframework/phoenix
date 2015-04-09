defmodule Mix.Tasks.Phoenix.Digest do
  use Mix.Task
  @default_input_path "priv/static"

  @shortdoc "Digests and compress static files."

  @moduledoc """
  Digests and compress static files.

      mix phoenix.digest priv/static -o public/assets

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

  @doc false
  def run([input|args]) do
    {args, _, _} = OptionParser.parse(args, aliases: [o: :output])
    input_path = input || @default_input_path
    output_path = args[:output] || input_path

    case Phoenix.Digester.compile(input_path, output_path) do
      :ok -> Mix.shell.info [:green, "Check your digested files at '#{output_path}'."]
      {:error, :invalid_path} -> Mix.raise "The input path '#{input_path}' does not exist."
    end
  end
end
