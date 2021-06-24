defmodule <%= @web_namespace %>.Mailer do
  use Swoosh.Mailer, otp_app: :<%= if @in_umbrella do %><%= @web_app_name %><% else %><%= @app_name %><% end %>
end
