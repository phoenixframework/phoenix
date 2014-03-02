defmodule <%= application_module %>.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :<%= Mix.Utils.underscore(application_module) %>
  get "/", <%= application_module %>.Controllers.Pages, :index, as: :page
end
