defmodule <%= inspect context.web_module %>.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use <%= inspect context.web_module %>, :controller

  <%= if schema.generate? do %># This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: <%= inspect context.web_module %>.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  <% end %># This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: <%= inspect context.web_module %>.ErrorHTML, json: <%= inspect context.web_module %>.ErrorJSON)
    |> render(:"404")
  end
end
