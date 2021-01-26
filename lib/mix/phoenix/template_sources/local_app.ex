defmodule Mix.Phoenix.TemplateSources.LocalApp do
  @moduledoc false

  @behaviour Mix.Phoenix.TemplateSource

  @impl true
  def render_template(template_path, binding) when is_list(binding) do
    if File.exists?(template_path) do
      {:ok, EEx.eval_file(template_path, [assigns: binding])}
    else
      {:error, :not_found}
    end
  end
end
