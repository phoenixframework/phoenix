
  @<%= schema_singular %>_fields <%= inspect Keyword.keys(schema_attrs) %>

  defmodule <%= inspect schema_alias %>Input do
    use Ecto.Schema

    embedded_schema do
  <%= for {k, _} <- schema_attrs do %>    field <%= inspect k %>, <%= inspect schema_types[k] %><%= schema_defaults[k] %>
  <% end %><%= for {k, _, m, _} <- schema_assocs do %>    belongs_to <%= inspect k %>, <%= m %><%= if(String.ends_with?(inspect(k), "_id"), do: "", else: ", foreign_key: " <> inspect(k) <> "_id") %>
  <% end %>  end
  end

  @doc """
  Returns the list of <%= schema_plural %>.

  ## Examples

      iex> list_<%= schema_plural %>()
      [%<%= inspect schema_module %>{}, ...]
  """
  def list_<%= schema_plural %>(opts \\ []) do
    Repo.all from(r in <%= inspect schema_module %>, limit: ^(opts[:limit] || 50))
  end

  @doc """
  Fetches a single <%= schema_singular %>.

  ## Examples

      iex> fetch_<%= schema_singular %>(123)
      {:ok, %<%= inspect schema_module %>{}}

      iex> fetch_<%= schema_singular %>(456)
      {:error, :not_found}
  """
  def fetch_<%= schema_singular %>(id) do
    case Repo.get(<%= inspect schema_module %>, id) do
      %<%= inspect schema_module %>{} = <%= schema_singular %> -> {:ok, <%= schema_singular %>}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Creates a <%= schema_singular %>.

  ## Examples

      iex> create_<%= schema_singular %>(<%= schema_singular %>, %{field: value})
      {:ok, %<%= inspect schema_module %>{}}

      iex> create_<%= schema_singular %>(<%= schema_singular %>, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_<%= schema_singular %>(attrs \\ []) do
    changeset = <%= schema_singular %>_input_changeset(%<%= inspect schema_module %>Input{}, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:<%= schema_singular %>_input, &apply_input_changes(&1, changeset))
    |> Ecto.Multi.run(:<%= schema_singular %>, fn ops ->
      %<%= inspect schema_module %>{}
      |> to_<%= schema_singular %>_changeset(ops.<%= schema_singular %>_input)
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{<%= schema_singular %>: <%= schema_singular %>}} -> {:ok, <%= schema_singular %>}
      # TODO map core struct to input struct errors?
      {:error, _op, _field, %{<%= schema_singular %>: changeset}} -> {:error, changeset}
    end
  end

  @doc """
  Updates a <%= schema_singular %>.

  ## Examples

      iex> update_<%= schema_singular %>(<%= schema_singular %>, %{field: new_value})
      {:ok, %<%= inspect schema_module %>{}}

      iex> update_<%= schema_singular %>(<%= schema_singular %>, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_<%= schema_singular %>(%<%= inspect schema_module %>{} = <%= schema_singular %>, attrs) do
    changeset = <%= schema_singular %>_input_changeset(<%= schema_singular %>, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:<%= schema_singular %>_input, &apply_input_changes(&1, changeset))
    |> Ecto.Multi.run(:<%= schema_singular %>, fn ops ->
      %<%= inspect schema_module %>{}
      |> to_<%= schema_singular %>_changeset(ops.<%= schema_singular %>_input)
      |> Repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{<%= schema_singular %>: <%= schema_singular %>}} -> {:ok, <%= schema_singular %>}
      # TODO map core struct to input struct errors?
      {:error, _op, _field, %{<%= schema_singular %>: changeset}} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a <%= inspect schema_module %>.

  ## Examples

      iex> delete_<%= schema_singular %>(<%= schema_singular %>)
      {:ok, %<%= inspect schema_module %>{}}

      iex> delete_<%= schema_singular %>(<%= schema_singular %>)
      {:error, %Ecto.Changeset{}}
  """
  def delete_<%= schema_singular %>(%<%= inspect schema_module %>{} = <%= schema_singular %>) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete(:<%= schema_singular %>, <%= schema_singular %>)
    |> Repo.transaction()
    |> case do
      {:ok, %{<%= schema_singular %>: <%= schema_singular %>}} -> {:ok, <%= schema_singular %>}
      {:error, _op, _field, %{<%= schema_singular %>: changeset}} -> {:error, changeset}
    end
  end


  @doc """
  Returns an `%Ecto.Changeset{}` for tracking <%= schema_singular %> changes.

  ## Examples

      iex> change_<%= schema_singular %>(<%= schema_singular %>)
      %Ecto.Changeset{source: %<%= inspect schema_module %>Input{}}
  """
  def change_<%= schema_singular %>(%<%= inspect schema_module %>{} = <%= schema_singular %>) do
    <%= schema_singular %>
    |> to_<%= schema_singular %>_input()
    |> <%= schema_singular %>_input_changeset()
  end

  defp <%= schema_singular %>_input_changeset(%<%= inspect schema_module %>{} = <%= schema_singular %>, attrs) do
    <%= schema_singular %>
    |> cast(attrs, [<%= Enum.map_join(schema_attrs, ", ", &inspect(elem(&1, 0))) %>])
    |> validate_required([<%= Enum.map_join(schema_attrs, ", ", &inspect(elem(&1, 0))) %>])
<%= for k <- schema_uniques do %>    |> unique_constraint(<%= inspect k %>)
<% end %>  end

  defp to_<%= schema_singular %>_changeset(%<%= inspect schema_module %>{} = <%= schema_singular %>, %<%= inspect schema_module %>Input{} = <%= schema_singular %>_input) do
    cast(<%= schema_singular %>, Map.take(<%= schema_singular %>_input, @<%= schema_singular %>_fields), @<%= schema_singular %>_fields)
  end

  defp to_<%= schema_singular %>_input(%<%= inspect schema_module %>{} = <%= schema_singular %>) do
    struct(<%= inspect schema_module %>Input, Map.take(<%= schema_singular %>, @<%= schema_singular %>_fields))
  end
