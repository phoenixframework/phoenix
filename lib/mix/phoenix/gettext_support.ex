defmodule Mix.Phoenix.GettextSupport do
  @moduledoc false

  @doc ~S"""
  Translates a message using Gettext if `gettext?` is true.

  The role provides context and determines which syntax should be used:

    * `:heex_attr` - Used in a HEEx attribute value.
    * `:eex` - Used in an EEx template.

  ## Examples

      iex> ~s|<tag attr=#{maybe_gettext("Hello", :heex_attr, true)} />|
      ~S|<tag attr={gettext("Hello")} />|

      iex> ~s|<tag attr=#{maybe_gettext("Hello", :heex_attr, false)} />|
      ~S|<tag attr="Hello" />|

      iex> ~s|<tag>#{maybe_gettext("Hello", :eex, true)}</tag>|
      ~S|<tag><%= gettext("Hello") %></tag>|

      iex> ~s|<tag>#{maybe_gettext("Hello", :eex, false)}</tag>|
      ~S|<tag>Hello</tag>|
  """
  @spec maybe_gettext(binary(), :heex_attr | :eex | :ex, boolean()) :: binary()
  def maybe_gettext(message, role, gettext?)

  def maybe_gettext(message, :heex_attr, gettext?) do
    if gettext? do
      ~s|{gettext(#{inspect(message)})}|
    else
      inspect(message)
    end
  end

  def maybe_gettext(message, :eex, gettext?) do
    if gettext? do
      ~s|<%= gettext(#{inspect(message)}) %>|
    else
      message
    end
  end
end
