defmodule <%= web_namespace %>.LiveHelpers do
  @moduledoc """
  Conveniences for LiveView templates.
  """

  import Phoenix.LiveView.Helpers

  def live_modal(socket, component, opts) do
    path = Keyword.fetch!(opts, :redirect_path)
    live_component(socket, <%= web_namespace %>.Modal, id: :modal, redirect_path: path, component: component, opts: opts)
  end

  def compute_title(title), do: "<%= web_namespace %> – #{title}"
end
