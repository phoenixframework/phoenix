defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionHTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_session_html/*"
end
