defmodule <%= module %> do
  use <%= base %>.Web, :model

  schema <%= inspect plural %> do
<%= for {_, {k, _}} <- attrs do %>    field <%= inspect k %>, <%= inspect types[k] %><%= defaults[k] %>
<% end %><%= for {_, {k, _, m, _}} <- assocs do %>    belongs_to <%= inspect k %>, <%= m %>
<% end %>
    timestamps
  end

  @required_fields ~w(<%= required_fields %>)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
<%= for {_, {_, k}} <- unique_constraints do %>    |> unique_constraint(<%= inspect k %>)
<% end %>  end
end
