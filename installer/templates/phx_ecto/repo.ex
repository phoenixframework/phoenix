defmodule <%= @app_module %>.Repo do
  use Ecto.Repo,
    otp_app: :<%= @app_name %>,
    adapter: <%= inspect @adapter_module %>
    socket_options: [:inet6]
end
