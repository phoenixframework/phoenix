defmodule Phoenix.Template.HTML do
  @moduledoc """
  The default HTML encoder that ships with Phoenix.

  It expects `{:safe, body}` as a safe response or
  body as a string which will be HTML escaped.
  """

  @doc """
  Encodes the HTML templates to iodata.
  """
  def encode_to_iodata!({:safe, body}), do: body
  def encode_to_iodata!(body) when is_binary(body), do: Plug.HTML.html_escape(body)
  def encode_to_iodata!(other), do: Phoenix.HTML.Safe.to_iodata(other)
end
