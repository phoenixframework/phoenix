# We don't run a server during test. If one is required,
# you can enable the server option below.
config :<%= @web_app_name %>, <%= @endpoint_module %>,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "<%= @secret_key_base_test %>",
  server: false
