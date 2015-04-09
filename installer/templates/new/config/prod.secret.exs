use Mix.Config

# Do not keep production secrets in the repository,
# instead read values from the environment.
config :<%= application_name %>, <%= application_module %>.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
