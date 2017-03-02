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
            dir: nil,
            opts: [],
            pre_existing?: false

  def valid?(context) do
    context =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def new(context_name, %Schema{} = schema, opts) do
    otp_app  = to_string(Mix.Phoenix.otp_app())
    base     = Module.concat([Mix.Phoenix.base()])
    module   = Module.concat(base, context_name)
    alias    = module |> Module.split() |> tl() |> Module.concat()
    basename = Phoenix.Naming.underscore(context_name)
    dir      = Path.join(["lib", otp_app, basename])
    file     = Path.join([dir, basename <> ".ex"])

    %Context{
      name: context_name,
      module: module,
      schema: schema,
      alias: alias,
      base_module: base,
      web_module: web_module(base),
      basename: basename,
      file: file,
      dir: dir,
      opts: opts,
      pre_existing?: File.exists?(file)}
  end

  defp web_module(base) do
    case base |> Module.split() |> Enum.reverse() do
      ["Web" | _] -> base
      _ -> Module.concat(base, "Web")
    end
  end
end
