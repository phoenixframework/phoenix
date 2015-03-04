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

    unless name do
      raise ArgumentError, "form_for/4 expects [name: NAME] to be given as options " <>
                           "when used with @conn"
    end

    name   = name |> to_string
    method = Keyword.get(opts, :method, "post") |> to_string

    %Phoenix.HTML.Form{
      name: name,
      method: method,
      model: %{},
      params: Map.get(conn.params, name) || %{},
      options: opts
    }
  end
end
