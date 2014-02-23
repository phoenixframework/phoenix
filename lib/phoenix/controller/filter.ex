defmodule Phoenix.Controller.Filter do

  defmacro __using__(_options) do
    quote do
      @before_compile unquote(__MODULE__)
      use Plug.Builder
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :after_plugs, accumulate: true)
    end
  end

  defmacro before_action(the_plug, options \\ []) do
    quote do
      plug(unquote(the_plug), unquote(options))
    end
  end

  defmacro after_action(the_plug, options \\ []) do
    quote do
      the_plug = unquote(the_plug)
      options = unquote(options)
      content= quote do: plug(unquote(the_plug), unquote(options))
      @after_plugs content
    end
  end

  defmacro __before_compile__(env) do
    module_name = atom_to_binary(env.module) <> ".AfterFilter"
    module = binary_to_atom(module_name)

    content = Module.get_attribute(env.module, :after_plugs)
    header = quote do: use Plug.Builder
    content = [ header | content ]

    quote do: Module.create(unquote(module), unquote(content))
  end

  def after_filter_module(module) do
    module_name = atom_to_binary(module) <> ".AfterFilter"
    try do
      binary_to_existing_atom(module_name)
    catch
      ArgumentError -> nil
    end
  end
end
