defmodule <%= inspect context.web_module %>.ChangesetJSON do
  @doc """
  Renders changeset errors.
  """<%= if core_components? do %>
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &<%= inspect context.web_module %>.CoreComponents.translate_error/1)}
  end<% else %>
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end
<%= if gettext? do %>
  defp translate_error({msg, opts}) do
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(<%= inspect context.web_module %>.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(<%= inspect context.web_module %>.Gettext, "errors", msg, opts)
    end
  end
<% else %>
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
end
