defmodule Mix.Tasks.Phx.New.Generator do
  import Mix.Generator

  @type base_path :: String.t
  @type app_path :: String.t
  @type web_path :: String.t
  @type path :: String.t
  @type opts :: Keyword.t
  @type app_name :: atom
  @type app_module :: Module.t
  @type binding ::Keyword.t

  @callback app(base_path, opts) :: {app_name, Module.t, path}
  @callback web_app(app_name, path, opts) :: {app_name, Module.t, path}
  @callback root_app(app_name, path, opts) :: {app_name, app_module, path}
  @callback gen_new(path, binding) :: :ok
  @callback gen_html(web_path, binding) :: :ok
  @callback gen_ecto(app_path, binding) :: :ok
  @callback gen_static(web_path, binding) :: :ok
  @callback gen_brunch(web_path, binding) :: :ok
  @callback gen_bare(path, binding) :: :ok


  defmacro __using__(_env) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      import Mix.Generator
      Module.register_attribute(__MODULE__, :templates, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    root = Path.expand("../../templates", __DIR__)
    templates_ast = for {_name, mappings} <- Module.get_attribute(env.module, :templates) do
      for {format, source, _} <- mappings, format != :keep do
        path = Path.join(root, source)
        quote do
          @external_resource unquote(path)
          def render(unquote(source)), do: unquote(File.read!(path))
        end
      end
    end

    quote do
      unquote(templates_ast)
      def template_files(name), do: Keyword.fetch!(@templates, name)
      # Embed missing files from Phoenix static.
      embed_text :phoenix_js, from_file: Path.expand("../../../priv/static/phoenix.js", unquote(__DIR__))
      embed_text :phoenix_png, from_file: Path.expand("../../../priv/static/phoenix.png", unquote(__DIR__))
      embed_text :phoenix_favicon, from_file: Path.expand("../../../priv/static/favicon.ico", unquote(__DIR__))
    end
  end

  defmacro template(name, mappings) do
    quote do
      @templates {unquote(name), unquote(mappings)}
    end
  end

  def copy_from(target_dir, mod, binding, mapping) when is_list(mapping) do
    app = Keyword.fetch!(binding, :app_name)
    for {format, source, target_path} <- mapping do
      target = Path.join(target_dir, String.replace(target_path, "app_name", app))

      case format do
        :keep ->
          File.mkdir_p!(target)
        :text ->
          create_file(target, mod.render(source))
        :append ->
          append_to(Path.dirname(target), Path.basename(target), mod.render(source))
        :eex  ->
          contents = EEx.eval_string(mod.render(source), binding, file: source)
          create_file(target, contents)
      end
    end
  end

  def append_to(path, file, contents) do
    file = Path.join(path, file)
    File.write!(file, File.read!(file) <> contents)
  end
end
