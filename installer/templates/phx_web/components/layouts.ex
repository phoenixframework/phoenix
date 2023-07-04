defmodule <%= @web_namespace %>.Layouts do
  use <%= @web_namespace %>, :html

  embed_templates "layouts/*"
end
