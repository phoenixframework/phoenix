use Mix.Config

<%= if ecto do %>config :<%= app_name %>, ecto_repos: [<%= app_module %>.Repo]
config :ecto, :json_library, Jason<% end %>

import_config "#{Mix.env}.exs"
