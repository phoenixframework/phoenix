defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>TOTPHTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_totp_html/*"
end
