use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or you later on).
#
# Alternatively, you can use the provided environment variables
# for configuration. Make sure to remove the secret values from
# this file, and remove the file from .gitignore so you can commit it.
config :<%= application_name %>, <%= application_module %>.Endpoint,
  secret_key_base: (System.get_env("SECRET_KEY_BASE") || "<%= prod_secret_key_base %>")
