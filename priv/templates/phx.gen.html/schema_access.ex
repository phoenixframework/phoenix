
  @doc """
  Returns the list of <%= schema.plural %>.

  ## Examples

      iex> list_<%= schema.plural %>()
      [%<%= inspect schema.module %>{}, ...]
  """
  def list_<%= schema.plural %> do
    Repo.all(<%= inspect schema.module %>)
  end

  @doc """
  Fetches a single <%= schema.singular %>.

  Raises `Ecto.NoResultsError` when called with `fetch_<%= schema.singular %>!/1`.

  ## Examples

      iex> fetch_<%= schema.singular %>(123)
      {:ok, %<%= inspect schema.module %>{}}

      iex> fetch_<%= schema.singular %>(456)
      {:error, :not_found}

      iex> fetch_<%= schema.singular %>!(456)
      ** (Ecto.NoResultsError)
  """
  def fetch_<%= schema.singular %>(id) do
    case Repo.get(<%= inspect schema.module %>, id) do
      %<%= inspect schema.module %>{} = <%= schema.singular %> -> {:ok, <%= schema.singular %>}
      nil -> {:error, :not_found}
    end
  end
  def fetch_<%= schema.singular %>!(id), do: Repo.get!(<%= inspect schema.module %>, id)

  @doc """
  Creates a <%= schema.singular %>.

  ## Examples

      iex> create_<%= schema.singular %>(<%= schema.singular %>, %{field: value})
      {:ok, %<%= inspect schema.module %>{}}

      iex> create_<%= schema.singular %>(<%= schema.singular %>, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_<%= schema.singular %>(attrs \\ %{}) do
    %<%= inspect schema.module %>{}
    |> <%= schema.singular %>_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a <%= schema.singular %>.

  ## Examples

      iex> update_<%= schema.singular %>(<%= schema.singular %>, %{field: new_value})
      {:ok, %<%= inspect schema.module %>{}}

      iex> update_<%= schema.singular %>(<%= schema.singular %>, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_<%= schema.singular %>(%<%= inspect schema.module %>{} = <%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> <%= schema.singular %>_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a <%= inspect schema.module %>.

  ## Examples

      iex> delete_<%= schema.singular %>(<%= schema.singular %>)
      {:ok, %<%= inspect schema.module %>{}}

      iex> delete_<%= schema.singular %>(<%= schema.singular %>)
      {:error, %Ecto.Changeset{}}
  """
  def delete_<%= schema.singular %>(%<%= inspect schema.module %>{} = <%= schema.singular %>) do
    Repo.delete(<%= schema.singular %>)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking <%= schema.singular %> changes.

  ## Examples

      iex> change_<%= schema.singular %>(<%= schema.singular %>)
      %Ecto.Changeset{source: %<%= inspect schema.module %>{}}
  """
  def change_<%= schema.singular %>(%<%= inspect schema.module %>{} = <%= schema.singular %>) do
    <%= schema.singular %>_changeset(<%= schema.singular %>, %{})
  end

  defp <%= schema.singular %>_changeset(%<%= inspect schema.module %>{} = <%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
    |> validate_required([<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
<%= for k <- schema.uniques do %>    |> unique_constraint(<%= inspect k %>)
<% end %>  end
