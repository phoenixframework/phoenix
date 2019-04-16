defmodule <%= web_namespace %>.PageLiveView do
  use Phoenix.LiveView
  import <%= web_namespace %>.Gettext

  @colours [
    "#5ED0FA",
    "#54D1DB",
    "#A368FC",
    "#F86A6A",
    "#FADB5F",
    "#65D6AD",
    "#127FBF",
    "#0E7C86",
    "#690CB0",
    "#AB091E",
    "#CB6E17",
    "#147D64"
  ]

  def render(assigns) do
    <%= web_namespace %>.PageView.render("hero.html", assigns)
  end

  def mount(_session, socket) do
    if connected?(socket), do: tick()
    {:ok, socket |> assign(tock: 1000) |> assign_colours()}
  end

  def handle_info(:tick, socket) do
    tick()
    {:noreply, socket |> update(:tock, &(&1 + 1)) |> assign_colours()}
  end

  defp colour(), do: @colours |> Enum.random()

  defp assign_colours(socket) do
    socket
    |> assign(:bgcolor, colour())
    |> assign(:fgcolor, colour())
  end

  defp tick(), do: Process.send_after(self(), :tick, 1000)
end