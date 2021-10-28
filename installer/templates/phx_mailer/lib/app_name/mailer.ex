defmodule <%= @app_module %>.Mailer do
  @moduledoc false
  
  use Swoosh.Mailer, otp_app: :<%= @app_name %>
end
