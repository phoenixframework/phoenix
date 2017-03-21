defmodule Mix.Phoenix.Context do
  @moduledoc false

  alias Mix.Phoenix.{Context, Schema}

  defstruct name: nil,
            module: nil,
            schema: nil,
            alias: nil,
            base_module: nil,
            web_module: nil,
            basename: nil,
            file: nil,
            test_file: nil,
            dir: nil,
            generate?: true,
            opts: []

  def valid?(context) do
    context =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def new(context_name, %Schema{} = schema, opts) do
    otp_app   = to_string(Mix.Phoenix.otp_app())
    base      = Module.concat([Mix.Phoenix.base()])
    module    = Module.concat(base, context_name)
    alias     = module |> Module.split() |> tl() |> Module.concat()
    basename  = Phoenix.Naming.underscore(context_name)
    dir       = Path.join(["lib", otp_app, basename])
    file      = Path.join([dir, basename <> ".ex"])
    test_file = Path.join(["test", basename <> "_test.exs"])
    generate? = Keyword.get(opts, :context, true)

    %Context{
      name: context_name,
      module: module,
      schema: schema,
      alias: alias,
      base_module: base,
      web_module: web_module(base),
      basename: basename,
      file: file,
      test_file: test_file,
      dir: dir,
      generate?: generate?,
      opts: opts}
  end

  def pre_existing?(%Context{file: file}), do: File.exists?(file)

  def pre_existing_tests?(%Context{test_file: file}), do: File.exists?(file)

  defp web_module(base) do
    case base |> Module.split() |> Enum.reverse() do
      ["Web" | _] -> base
      _ -> Module.concat(base, "Web")
    end
  end
end
