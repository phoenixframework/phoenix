defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationView do
  @moduledoc false
  use <%= inspect context.web_module %>, :view
end
