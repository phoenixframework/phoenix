# When using umbrella applications, this file should only
# configure what the :<%= app_name %> application itself.
# All other configuration goes to the umbrella root.
use Mix.Config

<%= if ecto do %>config :<%= app_name %>, ecto_repos: [<%= app_module %>.Repo]<% end %>

import_config "#{Mix.env}.exs"
