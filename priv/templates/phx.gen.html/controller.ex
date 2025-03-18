defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Controller do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  def index(conn, _params) do
    <%= schema.plural %> = <%= inspect context.alias %>.list_<%= schema.plural %>(<%= conn_scope %>)
    render(conn, :index, <%= schema.collection %>: <%= schema.plural %>)
  end

  def new(conn, _params) do<%= if scope do %>
    changeset =
      <%= inspect context.alias %>.change_<%= schema.singular %>(<%= context_scope_prefix %>%<%= inspect schema.alias %>{
        <%= scope.schema_key %>: <%= conn_scope %>.<%= Enum.join(scope.access_path, ".") %>
      })
<% else %>
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>(%<%= inspect schema.alias %>{})<% end %>
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{<%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    case <%= inspect context.alias %>.create_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        conn
        |> put_flash(:info, "<%= schema.human_singular %> created successfully.")
        |> redirect(to: ~p"<%= scope_conn_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"<%= primary_key %>" => <%= primary_key %>}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)
    render(conn, :show, <%= schema.singular %>: <%= schema.singular %>)
  end

  def edit(conn, %{"<%= primary_key %>" => <%= primary_key %>}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>)
    render(conn, :edit, <%= schema.singular %>: <%= schema.singular %>, changeset: changeset)
  end

  def update(conn, %{"<%= primary_key %>" => <%= primary_key %>, <%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)

    case <%= inspect context.alias %>.update_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        conn
        |> put_flash(:info, "<%= schema.human_singular %> updated successfully.")
        |> redirect(to: ~p"<%= scope_conn_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, <%= schema.singular %>: <%= schema.singular %>, changeset: changeset)
    end
  end

  def delete(conn, %{"<%= primary_key %>" => <%= primary_key %>}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)
    {:ok, _<%= schema.singular %>} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>)

    conn
    |> put_flash(:info, "<%= schema.human_singular %> deleted successfully.")
    |> redirect(to: ~p"<%= scope_conn_route_prefix %><%= schema.route_prefix %>")
  end
end
