defmodule Phoenix.View do

  defmacro __using__(_) do
    quote do
      path = Module.get_attribute(__MODULE__, :path) || __DIR__
      use Phoenix.Template.Compiler, path: path
      import unquote(__MODULE__)
    end
  end

  def safe({:safe, string}), do: {:safe, string}
  def safe(string), do: {:safe, string}

  def unsafe({:unsafe, string}), do: {:unsafe, string}
  def unsafe(string), do: {:unsafe, string}
end

