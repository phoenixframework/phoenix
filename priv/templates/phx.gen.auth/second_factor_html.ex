defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SecondFactorHTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_second_factor_html/*"
end
