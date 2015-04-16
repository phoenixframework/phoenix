defmodule <%= module %>Controller do
  use <%= base %>.Web, :controller

  alias <%= module %>

  plug :scrub_params, <%= inspect singular %> when action in [:create, :update]
  plug :action

  def index(conn, _params) do
    <%= plural %> = Repo.all(<%= alias %>)
    render conn, "index.html", <%= plural %>: <%= plural %>
  end

  def new(conn, _params) do
    changeset = <%= alias %>.changeset(%<%= alias %>{})
    render conn, "new.html", changeset: changeset
  end

  def create(conn, %{<%= inspect singular %> => <%= singular %>_params}) do
    changeset = <%= alias %>.changeset(%<%= alias %>{}, <%= singular %>_params)

    if changeset.valid? do
      Repo.insert(changeset)

      conn
      |> put_flash(:info, "<%= alias %> created successfully.")
      |> redirect(to: <%= singular %>_path(conn, :index))
    else
      render conn, "new.html", changeset: changeset
    end
  end

  def show(conn, %{"id" => id}) do
    <%= singular %> = Repo.get(<%= alias %>, id)
    render conn, "show.html", <%= singular %>: <%= singular %>
  end

  def edit(conn, %{"id" => id}) do
    <%= singular %> = Repo.get(<%= alias %>, id)
    changeset = <%= alias %>.changeset(<%= singular %>)
    render conn, "edit.html", <%= singular %>: <%= singular %>, changeset: changeset
  end

  def update(conn, %{"id" => id, <%= inspect singular %> => <%= singular %>_params}) do
    <%= singular %> = Repo.get(<%= alias %>, id)
    changeset = <%= alias %>.changeset(<%= singular %>, <%= singular %>_params)

    if changeset.valid? do
      Repo.update(changeset)

      conn
      |> put_flash(:info, "<%= alias %> updated successfully.")
      |> redirect(to: <%= singular %>_path(conn, :index))
    else
      render conn, "edit.html", <%= singular %>: <%= singular %>, changeset: changeset
    end
  end

  def delete(conn, %{"id" => id}) do
    <%= singular %> = Repo.get(<%= alias %>, id)
    Repo.delete(<%= singular %>)

    conn
    |> put_flash(:info, "<%= alias %> deleted successfully.")
    |> redirect(to: <%= singular %>_path(conn, :index))
  end
end
