use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
#
# You should most probably document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or you later on).
config :<%= application_name %>, <%= application_module %>.Endpoint,
  secret_key_base: "<%= prod_secret_key_base %>"
