defmodule <%= @web_namespace %>.LayoutView do
  use <%= @web_namespace %>, :view
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}
end
