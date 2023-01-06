defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ResetPasswordHTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_reset_password_html/*"
end
