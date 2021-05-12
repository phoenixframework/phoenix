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
    |> put_view(<%= inspect context.web_module %>.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  <% end %># This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(<%= inspect context.web_module %>.ErrorView)
    |> render(:"404")
  end
end
