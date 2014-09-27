defmodule <%= application_module %>.Router do
  use Phoenix.Router

  get "/", <%= application_module %>.PageController, :index, as: :pages

end
