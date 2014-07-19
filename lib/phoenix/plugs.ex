defmodule Phoenix.Plugs do

  @doc ~S"""
  Returns true if provided function or module Plug exists in configured plugs

  Useful in __before_compile__ hooks to auto include required plugs if not
  already included by the module

  Examples

  quote do
    unless Plugs.plugged?(@plugs, :action) do
      plug :action
    end
  end

  iex> Plugs.plugged?([{Plugs.ContentTypeFetcher, []}], ContentTypeFetcher)
  true
  """
  def plugged?(plugs, plug_name) do
    Enum.find plugs, fn {plug, _opts} -> plug == plug_name end
  end

end
