# Since configuration is shared in umbrella projects, this file
# should only configure the :<%= app_name %> application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config<%= if ecto do %>

config :<%= app_name %>, ecto_repos: [<%= app_module %>.Repo]<% end %>

import_config "#{Mix.env()}.exs"
