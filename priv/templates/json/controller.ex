defmodule <%= module %>Controller do
  use <%= base %>.Web, :controller

  alias <%= module %>

  plug :scrub_params, <%= inspect singular %> when action in [:create, :update]

  def index(conn, _params) do
    <%= plural %> = Repo.all(<%= alias %>)
    render(conn, "index.json", <%= plural %>: <%= plural %>)
  end

  def create(conn, %{<%= inspect singular %> => <%= singular %>_params}) do
    changeset = <%= alias %>.changeset(%<%= alias %>{}, <%= singular %>_params)

    if changeset.valid? do
      <%= singular %> = Repo.insert(changeset)
      render(conn, "show.json", <%= singular %>: <%= singular %>)
    else
      conn
      |> put_status(:unprocessable_entity)
      |> render(<%= base %>.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    <%= singular %> = Repo.get!(<%= alias %>, id)
    render conn, "show.json", <%= singular %>: <%= singular %>
  end

  def update(conn, %{"id" => id, <%= inspect singular %> => <%= singular %>_params}) do
    <%= singular %> = Repo.get!(<%= alias %>, id)
    changeset = <%= alias %>.changeset(<%= singular %>, <%= singular %>_params)

    if changeset.valid? do
      <%= singular %> = Repo.update(changeset)
      render(conn, "show.json", <%= singular %>: <%= singular %>)
    else
      conn
      |> put_status(:unprocessable_entity)
      |> render(<%= base %>.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    <%= singular %> = Repo.get!(<%= alias %>, id)

    <%= singular %> = Repo.delete(<%= singular %>)
    render(conn, "show.json", <%= singular %>: <%= singular %>)
  end
end
