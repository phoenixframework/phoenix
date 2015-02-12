defmodule Phoenix.HTML do
  @moduledoc """
  Conveniences for working HTML strings and templates.

  When used, it imports this module and, in the future,
  many other modules under the `Phoenix.HTML` namespace.

  ## HTML Safe

  One of the main responsibilities of this module is to
  provide convenience functions for escaping and marking
  HTML code as safe.

  In order to mark some code as safe, developers should
  invoke the `safe/1` function. User data or data coming
  from the database should never be marked as safe, it
  should be kept as regular data or given to `html_escape/1`
  so its contents are escaped and the end result is considered
  to be safe.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.HTML

      use Phoenix.HTML.Controller
    end
  end

  @type safe   :: {:safe, unsafe}
  @type unsafe :: iodata

  @doc """
  Marks the given value as safe, therefore its contents won't be escaped.

      iex> Phoenix.HTML.safe("<hello>")
      {:safe, "<hello>"}
      iex> Phoenix.HTML.safe({:safe, "<hello>"})
      {:safe, "<hello>"}

  """
  @spec safe(unsafe | safe) :: safe
  def safe({:safe, value}), do: {:safe, value}
  def safe(value) when is_binary(value) or is_list(value), do: {:safe, value}

  @doc """
  Concatenates data safely.

      iex> Phoenix.HTML.safe_concat("<hello>", "<world>")
      {:safe, ["&lt;hello&gt;"|"&lt;world&gt;"]}

      iex> Phoenix.HTML.safe_concat({:safe, "<hello>"}, "<world>")
      {:safe, ["<hello>"|"&lt;world&gt;"]}

      iex> Phoenix.HTML.safe_concat("<hello>", {:safe, "<world>"})
      {:safe, ["&lt;hello&gt;"|"<world>"]}

      iex> Phoenix.HTML.safe_concat({:safe, "<hello>"}, {:safe, "<world>"})
      {:safe, ["<hello>"|"<world>"]}

  """
  @spec safe_concat(unsafe | safe, unsafe | safe) :: safe
  def safe_concat({:safe, data1}, {:safe, data2}), do: {:safe, [data1|data2]}
  def safe_concat({:safe, data1}, data2), do: {:safe, [data1|io_escape(data2)]}
  def safe_concat(data1, {:safe, data2}), do: {:safe, [io_escape(data1)|data2]}
  def safe_concat(data1, data2), do: {:safe, [io_escape(data1)|io_escape(data2)]}

  @doc """
  Escapes the HTML entities in the given string, marking it as safe.

      iex> Phoenix.HTML.html_escape("<hello>")
      {:safe, "&lt;hello&gt;"}

      iex> Phoenix.HTML.html_escape('<hello>')
      {:safe, ["&lt;", 104, 101, 108, 108, 111, "&gt;"]}

      iex> Phoenix.HTML.html_escape({:safe, "<hello>"})
      {:safe, "<hello>"}
  """
  @spec html_escape(safe | unsafe) :: safe
  def html_escape({:safe, data}) do
    {:safe, data}
  end

  def html_escape(data) do
    {:safe, io_escape(data)}
  end

  defp io_escape(data) when is_binary(data) do
    Phoenix.HTML.Safe.BitString.to_iodata(data)
  end

  defp io_escape(data) when is_list(data) do
    Phoenix.HTML.Safe.List.to_iodata(data)
  end
end
