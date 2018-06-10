defmodule <%= app_module %>.Repo do
  use Ecto.Repo,
    otp_app: <%= inspect app_name %>,
    adapter: <%= inspect adapter_module %>
end
