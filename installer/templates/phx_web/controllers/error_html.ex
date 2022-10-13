defmodule <%= @web_namespace %>.ErrorHTML do
  use <%= @web_namespace %>, :html

  # embed_templates "errors/*"

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
