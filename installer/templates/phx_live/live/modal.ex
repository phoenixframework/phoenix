defmodule <%= web_namespace %>.Modal do
  @moduledoc """
  A Modal component that wraps other components.

  Includes live navigation for closed and open states for proper URL
  handling.

  ## Example Usage

  <%%= live_modal @socket, <%= web_namespace %>.PostLive.Form,
    id: @post.id,
    action: @live_view_action,
    post: @post,
    redirect_path: Routes.post_show_path(@socket, :show, @post) %>

  """
  use <%= web_namespace %>, :live_component

  def render(assigns) do
    ~L"""
    <div id="<%%= @id %>" class="phx-modal"
      phx-capture-click="close"
      phx-window-keydown="close"
      phx-key="escape"
      phx-target="#<%%= @id %>"
      phx-page-loading>

      <div class="phx-modal-content">
        <%%= live_patch raw("&times;"), to: @redirect_path, id: "close", class: "phx-modal-close" %>
        <%%= live_component @socket, @component, @opts %>
      </div>
    </div>
    """
  end

  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.redirect_path)}
  end
end
