defmodule <%= @web_namespace %>.Router do
  use <%= @web_namespace %>, :router<%= if @html do %>

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {<%= @web_namespace %>.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end<% end %>

  pipeline :api do
    plug :accepts, ["json"]
  end<%= if @html do %>

  scope "/", <%= @web_namespace %> do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", <%= @web_namespace %> do
  #   pipe_through :api
  # end<% else %>

  scope "/api", <%= @web_namespace %> do
    pipe_through :api
  end<% end %><%= if @dashboard || @mailer do %>

  # Enable <%= [@dashboard && "LiveDashboard", @mailer && "Swoosh mailbox preview"] |> Enum.filter(&(&1)) |> Enum.join(" and ") %> in development
  if Application.compile_env(:<%= @app_name %>, :dev_routes) do<% end %><%= if @dashboard do %>
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/" do<%= if @html do %>
      pipe_through :browser<% else %>
      pipe_through [:fetch_session, :protect_from_forgery]<% end %>

      live_dashboard "/dashboard", metrics: <%= @web_namespace %>.Telemetry
    end
<% end %><%= if @mailer do %>
    scope "/dev" do<%= if @html do %>
      pipe_through :browser<% else %>
      pipe_through [:fetch_session, :protect_from_forgery]<% end %>

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end<% end %>
end
