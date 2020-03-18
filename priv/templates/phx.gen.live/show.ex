defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Show do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Showing <%= schema.human_singular %>")}
  end

  def handle_params(%{"id" => id}, _, socket) do
    {:noreply, assign(socket, :<%= schema.singular %>, <%= inspect context.alias %>.get_<%= schema.singular %>!(id))}
  end
end
