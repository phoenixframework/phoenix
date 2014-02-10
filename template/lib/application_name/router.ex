defmodule <%= application_module %>.Router do
  use Phoenix.Router, port: 4000

  get "/", <%= application_module %>.Controllers.Pages, :index, as: :page
end
