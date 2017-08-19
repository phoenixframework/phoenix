defmodule Phoenix.CodeReloader.Colors do
  @moduledoc false

  def to_html(string) do
    string
    |> Plug.HTML.html_escape()
    |> String.split(~r/\e\[(\d+)m/, include_captures: true, trim: true)
    |> compose()
  end

  @styles [
    red: %{"color" => "red"},
    blue: %{"color" => "blue"},
    yellow: %{"color" => "#b3b30a"},
    bright: %{"font-weight" => "bold"},
    underline: %{"font-style" => "underlines"},
  ]

  for {ansi, css} <- @styles do
    code = apply(IO.ANSI, ansi, [])

    defp css_style(unquote(code)) do
      unquote(Macro.escape(css))
    end
  end

  defp css_style(_), do: %{}


  defp compose(parts, result \\ "", styles \\ %{}, have_open_tag \\ false)

  defp compose([], result, _styles, _have_open_tag) do
    result
  end

  # Reset code – add a close tag if necessary and reset the styles map to be empty
  defp compose(["\e[0m" | rest], result, _styles, have_open_tag) do
    result = result <> close_tag(have_open_tag)
    compose(rest, result, %{}, false)
  end

  defp compose([code = <<"\e[", _::binary>> | rest], result, styles, have_open_tag) do
    styles = Map.merge(styles, css_style(code))
    compose(rest, result, styles, have_open_tag)
  end

  defp compose([text | rest], result, styles, have_open_tag) do
    result = result <> close_tag(have_open_tag) <> open_tag(styles) <> text
    compose(rest, result, styles, !Enum.empty?(styles))
  end

  defp open_tag(styles) when map_size(styles) == 0,
    do: ""
  defp open_tag(styles) do
    css = Enum.map_join(styles, "; ", fn {key, value} -> "#{key}: #{value}" end)
    ~s(<span style="#{css}">)
  end

  defp close_tag(true), do: "</span>"
  defp close_tag(false), do: ""
end
