defmodule <%= application_module %>.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :<%= application_name %>
  get "/", <%= application_module %>.PageController, :index, as: :page
end
