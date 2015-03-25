use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
config :<%= application_name %>, <%= application_module %>.Endpoint,
  secret_key_base: "<%= prod_secret_key_base %>"
