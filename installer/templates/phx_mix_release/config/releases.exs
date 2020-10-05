# In this file, we load run-time configuration and secrets
# from environment variables via Mix Releases. If you have
# any use case specific configuration that needs to be dealt
# with be sure to checkout the `Config.Provider` documentation.

import Config
import System, only: [fetch_env!: 1]

# Fetch Phoenix related configurations
phoenix_secret_key_base = fetch_env!("APP_SECRET_KEY_BASE")
phoenix_host = fetch_env!("APP_HOST")
phoenix_origin = fetch_env!("APP_ORIGIN")
phoenix_port = "APP_PORT" |> fetch_env!() |> String.to_integer()
<%= if ecto do %>
# Fetch Ecto related configurations
database_name = fetch_env!("DATABASE_NAME")
database_user = fetch_env!("DATABASE_USER")
database_password = fetch_env!("DATABASE_PASSWORD")
database_host = fetch_env!("DATABASE_HOST")
database_port = fetch_env!("DATABASE_PORT")
database_pool_size = "DATABASE_POOL_SIZE" |> fetch_env!() |> String.to_integer()
<% end %>
# Set run-time Phoenix configuration options
config :<%= app_name %>, <%= endpoint_module %>,
  url: [host: phoenix_host, port: phoenix_port],
  check_origin: phoenix_origin,
  http: [:inet6, port: phoenix_port],
  secret_key_base: phoenix_secret_key_base
<%= if ecto do %>
# Set run-time Ecto configuration options
config :<%= app_name %>, <%= app_module %>.Repo,
  database: database_name,
  username: database_user,
  password: database_password,
  hostname: database_host,
  port: database_port,
  pool_size: database_pool_size
<% else %>
# Set run-time Repo configuration options
#
# If your application also depends on a database, be sure to add
# those run-time configurations here as well. Something like:
#
#     database_name = fetch_env!("DATABASE_NAME")
#     database_user = fetch_env!("DATABASE_USER")
#     database_password = fetch_env!("DATABASE_PASSWORD")
#     database_host = fetch_env!("DATABASE_HOST")
#     database_port = fetch_env!("DATABASE_PORT")
#     database_pool_size = fetch_env!("DATABASE_POOL_SIZE")
#
#     config :<%= app_name %>, <%= app_module %>.Repo,
#       database: database_name,
#       username: database_user,
#       password: database_password,
#       hostname: database_host,
#       port: database_port,
#       pool_size: database_pool_size
<% end %>
