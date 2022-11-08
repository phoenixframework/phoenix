defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationHTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_confirmation_html/*"
end
