defmodule <%= application_module %>.Repo do
  use Ecto.Repo, otp_app: :<%= application_name %>
end
