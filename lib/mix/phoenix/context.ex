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
    otp_app  = Mix.Phoenix.otp_app()
    base     = context_base(otp_app)
    module   = Module.concat(base, context_name)
    alias    = module |> Module.split() |> tl() |> Module.concat()
    basename = Phoenix.Naming.underscore(context_name)
    dir      = context_dir(otp_app)
    file     = Path.join([dir, basename, basename <> ".ex"])

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

  defp context_dir(otp_app) do
    case Application.get_env(otp_app, :generators)[:context_app] do
      nil ->
        Path.join(["lib", to_string(otp_app)])
      context_app ->
        Path.join(["..", to_string(context_app), "lib", to_string(context_app)])
    end
  end

  defp context_base(otp_app) do
    case Application.get_env(otp_app, :generators)[:context_app] do
      nil -> Module.concat([Mix.Phoenix.base()])
      context_app ->
        [context_app |> to_string |> Phoenix.Naming.camelize()]
        |> Module.concat()
    end
  end

  defp web_module(base) do
    case base |> Module.split() |> Enum.reverse() do
      ["Web" | _] -> base
      _ -> Module.concat(base, "Web")
    end
  end
end
