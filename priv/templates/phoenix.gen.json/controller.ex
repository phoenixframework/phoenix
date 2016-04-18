defmodule <%= module %>Controller do
  use <%= base %>.Web, :controller

  alias <%= module %>

  def index(conn, _params) do
    <%= plural %> = Repo.all(<%= alias %>)
    render(conn, "index.json", <%= plural %>: <%= plural %>)
  end

  def create(conn, %{<%= inspect singular %> => <%= singular %>_params}) do
    changeset = <%= alias %>.changeset(%<%= alias %>{}, <%= singular %>_params)

    case Repo.insert(changeset) do
      {:ok, <%= singular %>} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", <%= singular %>_path(conn, :show, <%= singular %>))
        |> render("show.json", <%= singular %>: <%= singular %>)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(<%= base %>.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    <%= singular %> = Repo.get!(<%= alias %>, id)
    render(conn, "show.json", <%= singular %>: <%= singular %>)
  end

  def update(conn, %{"id" => id, <%= inspect singular %> => <%= singular %>_params}) do
    <%= singular %> = Repo.get!(<%= alias %>, id)
    changeset = <%= alias %>.changeset(<%= singular %>, <%= singular %>_params)

    case Repo.update(changeset) do
      {:ok, <%= singular %>} ->
        render(conn, "show.json", <%= singular %>: <%= singular %>)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(<%= base %>.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    <%= singular %> = Repo.get!(<%= alias %>, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(<%= singular %>)

    send_resp(conn, :no_content, "")
  end
end
