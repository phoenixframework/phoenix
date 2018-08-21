defmodule <%= web_namespace %>.Router do
  use <%= web_namespace %>, :router<%= if html do %>

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end<% end %>

  pipeline :api do
    plug :accepts, ["json"]
  end<%= if html do %>

  scope "/", <%= web_namespace %> do
    # Use the default browser stack
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", <%= web_namespace %> do
  #   pipe_through :api
  # end<% else %>

  scope "/api", <%= web_namespace %> do
    pipe_through :api
  end<% end %>
end
