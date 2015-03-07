defmodule <%= module %> do
  use <%= base %>.Web, :model

  schema <%= inspect plural %> do
<%= for {k, _} <- attrs do %>    field <%= inspect k %>, <%= inspect types[k] %><%= defaults[k] %>
<% end %>
    timestamps
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If `params` are nil, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ nil) do
    cast(model, params, ~w(<%= Enum.map_join(attrs, " ", &elem(&1, 0)) %>), ~w())
  end
end
