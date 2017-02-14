defmodule Mix.Phoenix.Context do
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
            pre_existing?: false,
            inputs: []


  def new(context_name, %Schema{} = schema, opts) do
    base     = Module.concat([Mix.Phoenix.base()])
    module   = Module.concat(base, context_name)
    alias    = module |> Module.split() |> tl() |> Module.concat()
    basename = Phoenix.Naming.underscore(context_name)
    dir      = Path.join(["lib", basename])
    file     = Path.join(["lib", basename <> ".ex"])

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
      inputs: inputs(schema),
      pre_existing?: File.exists?(file)}
  end
  defp web_module(base) do
    case base |> Module.split() |> Enum.reverse() do
      ["Web" | _] -> base
      _ -> Module.concat(base, "Web")
    end
  end

  def inject_schema_access(%Context{} = context, binding, paths) do
    unless context.pre_existing? do
      File.mkdir_p!(context.dir)
      File.write!(context.file, Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.html/context.ex", binding))
    end
    schema_content = Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.html/schema_access.ex", binding)

    context.file
    |> File.read!()
    |> String.trim_trailing()
    |> String.trim_trailing("end")
    |> EEx.eval_string(binding)
    |> Kernel.<>(schema_content)
    |> Kernel.<>("end\n")
    |> write_context(context)

    context
  end
  defp write_context(content, context), do: File.write!(context.file, content)


  defp inputs(%Schema{} = schema) do
    Enum.map(schema.attrs, fn
      {_, {:array, _}} ->
        {nil, nil, nil}
      {_, {:references, _}} ->
        {nil, nil, nil}
      {key, :integer} ->
        {label(key), ~s(<%= number_input f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :float} ->
        {label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>), error(key)}
      {key, :decimal} ->
        {label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>), error(key)}
      {key, :boolean} ->
        {label(key), ~s(<%= checkbox f, #{inspect(key)}, class: "checkbox" %>), error(key)}
      {key, :text} ->
        {label(key), ~s(<%= textarea f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :date} ->
        {label(key), ~s(<%= date_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :time} ->
        {label(key), ~s(<%= time_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :utc_datetime} ->
        {label(key), ~s(<%= datetime_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :naive_datetime} ->
        {label(key), ~s(<%= datetime_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, _}  ->
        {label(key), ~s(<%= text_input f, #{inspect(key)}, class: "form-control" %>), error(key)}
    end)
  end

  defp label(key) do
    ~s(<%= label f, #{inspect(key)}, class: "control-label" %>)
  end

  defp error(field) do
    ~s(<%= error_tag f, #{inspect(field)} %>)
  end
end
