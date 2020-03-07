defmodule <%= web_namespace %>.Router do
  use <%= web_namespace %>, :router<%= if html do %>

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session<%= if live do %>
    plug :fetch_live_flash
    plug :put_root_layout, {<%= web_namespace %>.LayoutView, :root}
    plug :put_live_layout, {<%= web_namespace %>.LayoutView, :live}
    plug :put_layout, {<%= web_namespace %>.LayoutView, :app}<% else %>
    plug :fetch_flash<% end %>
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end<% end %>

  pipeline :api do
    plug :accepts, ["json"]
  end<%= if html do %>

  scope "/", <%= web_namespace %> do
    pipe_through :browser

    <%= if live do %>live "/", PageLive, :index<% else %>get "/", PageController, :index<% end %>
  end

  # Other scopes may use custom stacks.
  # scope "/api", <%= web_namespace %> do
  #   pipe_through :api
  # end<% else %>

  scope "/api", <%= web_namespace %> do
    pipe_through :api
  end<% end %>
end
