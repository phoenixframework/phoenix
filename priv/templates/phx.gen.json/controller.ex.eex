defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Controller do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  action_fallback <%= inspect context.web_module %>.FallbackController

  def index(conn, _params) do
    <%= schema.plural %> = <%= inspect context.alias %>.list_<%= schema.plural %>(<%= conn_scope %>)
    render(conn, :index, <%= schema.plural %>: <%= schema.plural %>)
  end

  def create(conn, %{<%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    with {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} <- <%= inspect context.alias %>.create_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"<%= schema.api_route_prefix %><%= scope_conn_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")
      |> render(:show, <%= schema.singular %>: <%= schema.singular %>)
    end
  end

  def show(conn, %{"<%= primary_key %>" => <%= primary_key %>}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)
    render(conn, :show, <%= schema.singular %>: <%= schema.singular %>)
  end

  def update(conn, %{"<%= primary_key %>" => <%= primary_key %>, <%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)

    with {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} <- <%= inspect context.alias %>.update_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>, <%= schema.singular %>_params) do
      render(conn, :show, <%= schema.singular %>: <%= schema.singular %>)
    end
  end

  def delete(conn, %{"<%= primary_key %>" => <%= primary_key %>}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)

    with {:ok, %<%= inspect schema.alias %>{}} <- <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>) do
      send_resp(conn, :no_content, "")
    end
  end
end
