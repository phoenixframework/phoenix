defmodule <%= app_module %>.Repo do
  use Ecto.Repo, otp_app: :<%= app_name %>
end
