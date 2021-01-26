defmodule Mix.Phoenix.TemplateSources.Phoenix do
  @moduledoc false

  @behaviour Mix.Phoenix.TemplateSource

  @impl true
  def render_template(template_path, binding) when is_list(binding) do
    path = phoenix_template_path(template_path)
    if File.exists?(path) do
      {:ok, EEx.eval_file(path, [assigns: binding])}
    else
      {:error, :not_found}
    end
  end

  defp phoenix_template_path(template_path) do
    Application.app_dir(:phoenix, template_path)
  end
end
