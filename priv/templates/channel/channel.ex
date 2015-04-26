defmodule <%= module %>Channel do
  use <%= base %>.Web, :channel

  def join("<%= plural %>:lobby", _auth_message, socket) do
    {:ok, socket}
  end

  def join("<%= plural %>:" <> _<%= singular %>_id, _auth_message, socket) do
    {:ok, socket}
  end

  <%= for event <- events do %>
    def handle_in("<%= event %>", attrs, socket) do
      broadcast! socket, event, attrs
      {:noreply, socket}
    end
  <% end %>
end
