defmodule <%= @app_module %>.Oban do
  use Oban, otp_app: :<%= @app_name %>
end
