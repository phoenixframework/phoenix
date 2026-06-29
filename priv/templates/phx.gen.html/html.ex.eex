defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>HTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_html/*"

  @doc """
  Renders a <%= schema.singular %> form.

  The form is defined in the template at
  <%= schema.singular %>_html/<%= schema.singular %>_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def <%= schema.singular %>_form(assigns)
end
