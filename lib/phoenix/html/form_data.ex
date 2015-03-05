defprotocol Phoenix.HTML.FormData do
  @moduledoc """
  Converts a data structure into a `Phoenix.HTML.Form` struct.
  """

  @doc """
  Converts a data structure into a `Phoenix.HTML.Form` struct.

  The options are the same options given to `form_for/4`. It
  can be used by implementations to configure their behaviour
  and it must be stored in the underlying struct, with any
  custom field removed.
  """
  def to_form(data, options)
end

defimpl Phoenix.HTML.FormData, for: Plug.Conn do
  def to_form(conn, opts) do
    {name, opts} = Keyword.pop(opts, :name)
    name = to_string(name || no_name_error!)

    %Phoenix.HTML.Form{
      source: conn,
      name: name,
      model: %{},
      params: Map.get(conn.params, name) || %{},
      options: opts
    }
  end

  defp no_name_error! do
    raise ArgumentError, "form_for/4 expects [name: NAME] to be given as option " <>
                         "when used with @conn"
  end
end
