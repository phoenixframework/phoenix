defmodule Phoenix.View.Base do

  defmacro __using__(_) do
    quote do
      @after_compile unquote(__MODULE__)
    end
  end

  defmacro __after_compile__(env, bytecode) do
    base_module = env.module
    base_dir    = Path.dirname(env.file)

    for {submod, path} <- implicit_subview_modules(base_module, base_dir) do
      Code.eval_quoted(quote do
        defmodule unquote(submod) do
          @path Path.join([unquote(path), "./"])
          use unquote(base_module)
        end
      end)
    end

    bytecode
  end

  def implicit_subview_modules(base_module, dir) do
    Path.wildcard(Path.join([dir, "**/*"]))
    |> Enum.filter(&subview?(&1))
    |> Enum.filter(&!subview_defined?(&1))
    |> Enum.map fn dir ->
      {Module.concat([base_module, Path.basename(dir)]), dir}
    end
  end

  def subview?(dir) do
    File.dir?(dir) && String.match?(Path.basename(dir), ~r/^[A-Z].*/)
  end

  def subview_defined?(dir) do
    view_module_name = Path.basename(dir) |> Mix.Utils.underscore
    File.exists?(Path.join([dir, "#{view_module_name}.ex"]))
  end
end
