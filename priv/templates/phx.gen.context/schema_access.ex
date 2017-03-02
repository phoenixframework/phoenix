
  alias <%= inspect schema.module %>

  @doc """
  Returns the list of <%= schema.plural %>.

  ## Examples

      iex> list_<%= schema.plural %>()
      [%<%= inspect schema.alias %>{}, ...]

  """
  def list_<%= schema.plural %> do
    Repo.all(<%= inspect schema.alias %>)
  end

  @doc """
  Gets a single <%= schema.singular %>.

  Raises `Ecto.NoResultsError` if the <%= schema.human_singular %> does not exist.

  ## Examples

      iex> get_<%= schema.singular %>!(123)
      %<%= inspect schema.alias %>{}

      iex> get_<%= schema.singular %>!(456)
      ** (Ecto.NoResultsError)

  """
  def get_<%= schema.singular %>!(id), do: Repo.get!(<%= inspect schema.alias %>, id)

  @doc """
  Creates a <%= schema.singular %>.

  ## Examples

      iex> create_<%= schema.singular %>(<%= schema.singular %>, %{field: value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> create_<%= schema.singular %>(<%= schema.singular %>, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_<%= schema.singular %>(attrs \\ %{}) do
    %<%= inspect schema.alias %>{}
    |> <%= schema.singular %>_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a <%= schema.singular %>.

  ## Examples

      iex> update_<%= schema.singular %>(<%= schema.singular %>, %{field: new_value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> update_<%= schema.singular %>(<%= schema.singular %>, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_<%= schema.singular %>(%<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> <%= schema.singular %>_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a <%= inspect schema.alias %>.

  ## Examples

      iex> delete_<%= schema.singular %>(<%= schema.singular %>)
      {:ok, %<%= inspect schema.alias %>{}}

      iex> delete_<%= schema.singular %>(<%= schema.singular %>)
      {:error, %Ecto.Changeset{}}

  """
  def delete_<%= schema.singular %>(%<%= inspect schema.alias %>{} = <%= schema.singular %>) do
    Repo.delete(<%= schema.singular %>)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking <%= schema.singular %> changes.

  ## Examples

      iex> change_<%= schema.singular %>(<%= schema.singular %>)
      %Ecto.Changeset{source: %<%= inspect schema.alias %>{}}

  """
  def change_<%= schema.singular %>(%<%= inspect schema.alias %>{} = <%= schema.singular %>) do
    <%= schema.singular %>_changeset(<%= schema.singular %>, %{})
  end

  defp <%= schema.singular %>_changeset(%<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
    |> validate_required([<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
<%= for k <- schema.uniques do %>    |> unique_constraint(<%= inspect k %>)
<% end %>  end
