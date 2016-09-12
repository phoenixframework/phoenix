use Mix.Config

<%= if ecto do %>config :<%= application_name %>, ecto_repos: [<%= application_module %>.Repo]<% end %>

<%= generator_config %>

import_config "#{Mix.env}.exs"
