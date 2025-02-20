
  alias <%= inspect schema.module %>
  alias <%= inspect scope.module %>

  @doc """
  Returns the list of <%= schema.plural %>.

  ## Examples

      iex> list_<%= schema.plural %>(scope)
      [%<%= inspect schema.alias %>{}, ...]

  """
  def list_<%= schema.plural %>(%<%= inspect scope.alias %>{} = <%= scope.name %>_scope) do
    Repo.all(from <%= schema.singular %> in <%= inspect schema.alias %>, where: <%= schema.singular %>.<%= scope.schema_key %> == ^<%= scope.name %>_scope.<%= Enum.join(scope.access_path, ".") %>)
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
  def get_<%= schema.singular %>!(%<%= inspect scope.alias %>{} = <%= scope.name %>_scope, id) do
    Repo.get_by!(<%= inspect schema.alias %>, [id: id, <%= scope.schema_key %>: <%= scope.name %>_scope.<%= Enum.join(scope.access_path, ".") %>])
  end

  @doc """
  Creates a <%= schema.singular %>.

  ## Examples

      iex> create_<%= schema.singular %>(%{field: value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> create_<%= schema.singular %>(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_<%= schema.singular %>(%<%= inspect scope.alias %>{} = <%= scope.name %>_scope, attrs \\ %{}) do
    %<%= inspect schema.alias %>{}
    |> <%= inspect schema.alias %>.changeset(attrs, <%= scope.name %>_scope)
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
  def update_<%= schema.singular %>(%<%= inspect scope.alias %>{} = <%= scope.name %>_scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs) do
    true = <%= schema.singular %>.<%= scope.schema_key %> == <%= scope.name %>_scope.<%= Enum.join(scope.access_path, ".") %>

    <%= schema.singular %>
    |> <%= inspect schema.alias %>.changeset(attrs, <%= scope.name %>_scope)
    |> Repo.update()
  end

  @doc """
  Deletes a <%= schema.singular %>.

  ## Examples

      iex> delete_<%= schema.singular %>(<%= schema.singular %>)
      {:ok, %<%= inspect schema.alias %>{}}

      iex> delete_<%= schema.singular %>(<%= schema.singular %>)
      {:error, %Ecto.Changeset{}}

  """
  def delete_<%= schema.singular %>(%<%= inspect scope.alias %>{} = <%= scope.name %>_scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>) do
    true = <%= schema.singular %>.<%= scope.schema_key %> == <%= scope.name %>_scope.<%= Enum.join(scope.access_path, ".") %>

    Repo.delete(<%= schema.singular %>)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking <%= schema.singular %> changes.

  ## Examples

      iex> change_<%= schema.singular %>(<%= schema.singular %>)
      %Ecto.Changeset{data: %<%= inspect schema.alias %>{}}

  """
  def change_<%= schema.singular %>(%<%= inspect scope.alias %>{} = <%= scope.name %>_scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs \\ %{}) do
    true = <%= schema.singular %>.<%= scope.schema_key %> == <%= scope.name %>_scope.<%= Enum.join(scope.access_path, ".") %>

    <%= inspect schema.alias %>.changeset(<%= schema.singular %>, attrs, <%= scope.name %>_scope)
  end
