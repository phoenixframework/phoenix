use Mix.Config

<%= if ecto do %>config :<%= app_name %>, ecto_repos: [<%= app_module %>.Repo]<% end %>

<%= generator_config %>

import_config "#{Mix.env}.exs"
