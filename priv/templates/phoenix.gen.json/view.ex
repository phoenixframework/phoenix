defmodule <%= module %>View do
  use <%= base %>.Web, :view

  def render("index.json", %{<%= plural %>: <%= plural %>}) do
    %{data: render_many(<%= plural %>, <%= module %>View, "<%= singular %>.json")}
  end

  def render("show.json", %{<%= singular %>: <%= singular %>}) do
    %{data: render_one(<%= singular %>, <%= module %>View, "<%= singular %>.json")}
  end

  def render("<%= singular %>.json", %{<%= singular %>: <%= singular %>}) do
    %{<%= json_fields %>}
  end
end
