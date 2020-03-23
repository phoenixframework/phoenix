defmodule <%= web_namespace %>.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """<%= if html do %>

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.

  Options:
  tag: Atom, the content_tag name. Default :span
  class: String, An html class attribute. Default "help-block"
  """
  def error_tag(form, field, options \\ []) do
    tag = Keyword.get(options, :tag, :span)
    klass = Keyword.get(options, :class, "help-block")
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(tag, translate_error(error), class: klass, 
        data: [phx_error_for: input_id(form, field)]
      )
    end)
  end<% end %><%= if gettext do %>

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(<%= web_namespace %>.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(<%= web_namespace %>.Gettext, "errors", msg, opts)
    end
  end<% else %>

  @doc """
  Translates an error message.
  """
  def translate_error({msg, opts}) do
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end<% end %>
end
