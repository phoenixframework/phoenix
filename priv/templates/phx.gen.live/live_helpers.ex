defmodule <%= inspect context.web_module %>.LiveHelpers do
  import Phoenix.LiveView
  import Phoenix.LiveView.Helpers

  alias Phoenix.LiveView.JS

  @doc """
  Renders a live component inside a modal.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <.modal return_to={Routes.<%= schema.singular %>_index_path(@socket, :index)}>
        <.live_component
          module={<%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.FormComponent}
          id={@<%= schema.singular %>.id || :new}
          title={@page_title}
          action={@live_action}
          return_to={Routes.<%= schema.singular %>_index_path(@socket, :index)}
          <%= schema.singular %>: @<%= schema.singular %>
        />
      </.modal>
  """
  def modal(assigns) do
    assigns = assign_new(assigns, :return_to, fn -> nil end)

    ~H"""
    <div id="modal" class="phx-modal fade-in" phx-remove={hide_modal()}>
      <div
        id="modal-content"
        class="phx-modal-content fade-in-scale"
        phx-click-away={JS.dispatch("click", to: "#close")}
        phx-window-keydown={JS.dispatch("click", to: "#close")}
        phx-key="escape"
      >
        <%%= if @return_to do %>
          <%%= live_patch "✖",
            to: @return_to,
            id: "close",
            class: "phx-modal-close",
            phx_click: hide_modal()
          %>
        <%% else %>
         <a id="close" href="#" class="phx-modal-close" phx-click={hide_modal()}>✖</a>
        <%% end %>

        <%%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp hide_modal(js \\ %JS{}) do
    js
    |> JS.hide(to: "#modal", transition: "fade-out")
    |> JS.hide(to: "#modal-content", transition: "fade-out-scale")
  end
end
