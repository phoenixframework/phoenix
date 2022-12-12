defmodule <%= inspect context.web_module %>.ChangesetJSON do
  @doc """
  Traverses and translates changeset errors.

  See `Ecto.Changeset.traverse_errors/2` and
  `<%= inspect context.web_module %>.CoreComponents.translate_error/1` for more details.
  """<%= if core_components? do %>) do
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &<%= inspect context.web_module %>.CoreComponents.translate_error/1)
  end<% else %><%= if gettext? do %>
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(<%= inspect context.web_module %>.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(<%= inspect context.web_module %>.Gettext, "errors", msg, opts)
    end
  end<% else %>
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(<%= inspect context.web_module %>.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(<%= inspect context.web_module %>.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end<% end %><% end %>

  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: translate_errors(changeset)}
  end
end
