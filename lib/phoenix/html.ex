defmodule Phoenix.HTML do
  @moduledoc """
  Helpers for working with HTML strings and templates.

  When used, it imports the given modules:

    * `Phoenix.HTML`- functions to handle HTML safety;

    * `Phoenix.HTML.Tag` - functions for generating HTML tags;

    * `Phoenix.HTML.Form` - functions for working with forms;

    * `Phoenix.HTML.Link` - functions for generating links and urls;

  ## HTML Safe

  One of the main responsibilities of this module is to
  provide convenience functions for escaping and marking
  HTML code as safe.

  By default, data output in templates is not considered
  safe:

      <%= "<hello>" %>

  will be shown as:

      &lt;hello&gt;

  User data or data coming from the database is almost never
  considered safe. However, in some cases, you may want to tag
  it as safe and show its original contents:

      <%= safe "<hello>" %>

  Keep in mind most helpers will automatically escape your data
  and return safe content:

      <%= tag :p, "<hello>" %>

  will properly output:

      <p>&lt;hello&gt;</p>

  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Phoenix.HTML.Link
      import Phoenix.HTML.Tag
    end
  end

  @typedoc "Guaranteed to be safe"
  @type safe    :: {:safe, iodata}

  @typedoc "May be safe or unsafe (i.e. it needs to be converted)"
  @type unsafe  :: Phoenix.HTML.Safe.t

  @doc """
  Provides `~e` sigil with HTML safe EEx syntax inside source files.

      iex> ~e"\""
      ...> Hello <%= "world" %>
      ...> "\""
      {:safe, [[["" | "Hello "] | "world"] | "\\n"]}

  """
  defmacro sigil_e(expr, opts) do
    handle_sigil(expr, opts, __CALLER__.line)
  end

  @doc """
  Provides `~E` sigil with HTML safe EEx syntax inside source files.

  This sigil does not support interpolation and is should be prefered
  rather than `~e`.

      iex> ~E"\""
      ...> Hello <%= "world" %>
      ...> "\""
      {:safe, [[["" | "Hello "] | "world"] | "\\n"]}

  """
  defmacro sigil_E(expr, opts) do
    handle_sigil(expr, opts, __CALLER__.line)
  end

  defp handle_sigil({:<<>>, _, [expr]}, [], line) do
    EEx.compile_string(expr, engine: Phoenix.HTML.Engine, line: line + 1)
  end

  defp handle_sigil(_, _, _) do
    raise ArgumentError, "interpolation not allowed in ~e sigil. " <>
                         "Remove the interpolation or use ~E instead"
  end

  @doc """
  Marks the given value as safe.

      iex> Phoenix.HTML.safe("<hello>")
      {:safe, "<hello>"}
      iex> Phoenix.HTML.safe({:safe, "<hello>"})
      {:safe, "<hello>"}

  """
  @spec safe(iodata | safe) :: safe
  def safe({:safe, value}), do: {:safe, value}
  def safe(value) when is_binary(value) or is_list(value), do: {:safe, value}

  @doc """
  Concatenates data in the given list safely.

      iex> safe_concat(["<hello>", "safe", "<world>"])
      {:safe, "&lt;hello&gt;safe&lt;world&gt;"}

  """
  @spec safe_concat([iodata | safe]) :: safe
  def safe_concat(list) when is_list(list) do
    Enum.reduce(list, {:safe, ""}, &safe_concat(&2, &1))
  end

  @doc """
  Concatenates data safely.

      iex> safe_concat("<hello>", "<world>")
      {:safe, "&lt;hello&gt;&lt;world&gt;"}

      iex> safe_concat({:safe, "<hello>"}, "<world>")
      {:safe, "<hello>&lt;world&gt;"}

      iex> safe_concat("<hello>", {:safe, "<world>"})
      {:safe, "&lt;hello&gt;<world>"}

      iex> safe_concat({:safe, "<hello>"}, {:safe, "<world>"})
      {:safe, "<hello><world>"}

      iex> safe_concat({:safe, "<hello>"}, {:safe, '<world>'})
      {:safe, ["<hello>"|'<world>']}

  """
  @spec safe_concat(iodata | safe, iodata | safe) :: safe
  def safe_concat({:safe, data1}, {:safe, data2}), do: {:safe, io_concat(data1, data2)}
  def safe_concat({:safe, data1}, data2), do: {:safe, io_concat(data1, io_escape(data2))}
  def safe_concat(data1, {:safe, data2}), do: {:safe, io_concat(io_escape(data1), data2)}
  def safe_concat(data1, data2), do: {:safe, io_concat(io_escape(data1), io_escape(data2))}

  defp io_escape(data) when is_binary(data),
    do: Phoenix.HTML.Safe.BitString.to_iodata(data)
  defp io_escape(data) when is_list(data),
    do: Phoenix.HTML.Safe.List.to_iodata(data)

  defp io_concat(d1, d2) when is_binary(d1) and is_binary(d2), do:
    d1 <> d2
  defp io_concat(d1, d2), do:
    [d1|d2]

  @doc """
  Escapes the HTML entities in the given term, returning iodata.

      iex> html_escape("<hello>")
      {:safe, "&lt;hello&gt;"}

      iex> html_escape('<hello>')
      {:safe, ["&lt;", 104, 101, 108, 108, 111, "&gt;"]}

      iex> html_escape(1)
      {:safe, "1"}

      iex> html_escape({:safe, "<hello>"})
      {:safe, "<hello>"}
  """
  @spec html_escape(unsafe) :: safe
  def html_escape({:safe, _} = safe),
    do: safe
  def html_escape(nil),
    do: {:safe, ""}
  def html_escape(other) when is_binary(other),
    do: {:safe, Phoenix.HTML.Safe.BitString.to_iodata(other)}
  def html_escape(other),
    do: {:safe, Phoenix.HTML.Safe.to_iodata(other)}
end
