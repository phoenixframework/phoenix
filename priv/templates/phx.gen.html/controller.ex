defmodule <%= inspect web_module %>.<%= inspect schema_alias %>Controller do
  use <%= inspect web_module %>, :controller

  def index(conn, _params) do
    <%= schema_plural %> = <%= inspect module %>.list_<%= schema_plural %>(limit: 100)
    render(conn, "index.html", <%= schema_plural %>: <%= schema_plural %>)
  end

  def new(conn, _params) do
    changeset = <%= inspect module %>.change_<%= schema_singular %>(%<%= inspect schema_module %>{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{<%= inspect schema_singular %> => <%= schema_singular %>_params}) do
    with {:ok, <%= schema_singular %>} <- <%= inspect module %>.create_<%= schema_singular %>(<%= schema_singular %>_params) do
      conn
      |> put_flash(:info, "<%= human_singular %> created successfully.")
      |> redirect(to: <%= schema_singular %>_path(conn, :index))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, <%= schema_singular %>} = <%= inspect module %>.fetch_<%= schema_singular %>(id) do
      render(conn, "show.html", <%= schema_singular %>: <%= schema_singular %>)
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, <%= schema_singular %>} = <%= inspect module %>.fetch_<%= schema_singular %>(id) do
      changeset = <%= inspect module %>.change_<%= schema_singular %>(<%= schema_singular %>)
      render(conn, "edit.html", <%= schema_singular %>: <%= schema_singular %>, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, <%= inspect schema_singular %> => <%= schema_singular %>_params}) do
    with {:ok, <%= schema_singular %>} <- <%= inspect module %>.fetch_<%= schema_singular %>(id),
         {:ok, <%= schema_singular %>} <- <%= inspect module %>.update_<%= schema_singular %>(<%= schema_singular %>, <%= schema_singular %>_params) do

      conn
      |> put_flash(:info, "<%= human_singular %> updated successfully.")
      |> redirect(to: <%= schema_singular %>_path(conn, :show, <%= schema_singular %>))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", <%= schema_singular %>: changeset.data, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, <%= schema_singular %>} <- <%= inspect module %>.fetch_<%= schema_singular %>(id),
         {:ok, <%= schema_singular %>} <- <%= inspect module %>.delete_<%= schema_singular %>(<%= schema_singular %>) do

      conn
      |> put_flash(:info, "<%= human_singular %> deleted successfully.")
      |> redirect(to: <%= schema_singular %>_path(conn, :index))
    end
  end
end
