defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationHTML do
  use <%= inspect context.web_module %>, :html
end
