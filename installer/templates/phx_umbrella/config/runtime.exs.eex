import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

config :<%= @web_app_name %>, <%= @endpoint_module %>,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  config :<%= @app_name %>, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
end
