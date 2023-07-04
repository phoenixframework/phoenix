defmodule <%= @web_namespace %>.ErrorHTML do
  use <%= @web_namespace %>, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates/1 call below
  # and add pages to the error directory:
  #
  #   * lib/<%= @lib_web_name %>/controllers/error_html/404.html.heex
  #   * lib/<%= @lib_web_name %>/controllers/error_html/500.html.heex
  #
  # embed_templates "error_html/*"

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
