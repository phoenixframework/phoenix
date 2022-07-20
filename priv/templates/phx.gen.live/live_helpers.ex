defmodule <%= inspect context.web_module %>.LiveHelpers do
  use Phoenix.Component

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
          <%= schema.singular %>={@<%= schema.singular %>}
          return_to={Routes.<%= schema.singular %>_index_path(@socket, :index)}
        />
      </.modal>
  """

  attr :return_to, :string, default: nil

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
          <.link id="close" patch={@return_to} phx-click={hide_modal()} class="phx-modal-close">✖</.link>
        <%% else %>
          <.link id="close" phx-click={hide_modal()} class="phx-modal-close">✖</.link>
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
