defmodule <%= inspect context.web_module %>.LiveHelpers do
  import Phoenix.LiveView.Helpers

  @doc """
  Renders a component inside the `<%= inspect context.web_module %>.Modal` component.

  The rendered modal receives a `:redirect_path` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%%= live_modal @socket, <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Form,
        id: @<%= schema.singular %>.id || :new,
        action: @live_view_action,
        <%= schema.singular %>: @<%= schema.singular %>,
        redirect_path: Routes.<%= schema.singular %>_index_path(@socket, :index) %>
  """
  def live_modal(socket, component, opts) do
    path = Keyword.fetch!(opts, :redirect_path)
    modal_opts = [id: :modal, redirect_path: path, component: component, opts: opts]
    live_component(socket, <%= inspect context.web_module %>.Modal, modal_opts)
  end
end
