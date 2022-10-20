defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Controller do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  def index(conn, _params) do
    <%= schema.plural %> = <%= inspect context.alias %>.list_<%= schema.plural %>()
    render(conn, :index, <%= schema.plural %>: <%= schema.plural %>)
  end

  def new(conn, _params) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>(%<%= inspect schema.alias %>{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{<%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    case <%= inspect context.alias %>.create_<%= schema.singular %>(<%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        conn
        |> put_flash(:info, "<%= schema.human_singular %> created successfully.")
        |> redirect(to: ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    render(conn, :show, <%= schema.singular %>: <%= schema.singular %>)
  end

  def edit(conn, %{"id" => id}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>(<%= schema.singular %>)
    render(conn, :edit, <%= schema.singular %>: <%= schema.singular %>, changeset: changeset)
  end

  def update(conn, %{"id" => id, <%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)

    case <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        conn
        |> put_flash(:info, "<%= schema.human_singular %> updated successfully.")
        |> redirect(to: ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, <%= schema.singular %>: <%= schema.singular %>, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    {:ok, _<%= schema.singular %>} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>)

    conn
    |> put_flash(:info, "<%= schema.human_singular %> deleted successfully.")
    |> redirect(to: ~p"<%= schema.route_prefix %>")
  end
end
