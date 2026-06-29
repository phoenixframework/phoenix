
  alias <%= inspect schema.module %>
  alias <%= inspect scope.module %>

  @doc """
  Subscribes to scoped notifications about any <%= schema.singular %> changes.

  The broadcasted messages match the pattern:

    * {:created, %<%= inspect schema.alias %>{}}
    * {:updated, %<%= inspect schema.alias %>{}}
    * {:deleted, %<%= inspect schema.alias %>{}}

  """
  def subscribe_<%= schema.plural %>(%<%= inspect scope.alias %>{} = scope) do
    key = scope.<%= Enum.join(scope.access_path, ".") %>

    Phoenix.PubSub.subscribe(<%= inspect context.base_module %>.PubSub, "<%= scope.name %>:#{key}:<%= schema.plural %>")
  end

  defp broadcast_<%= schema.singular %>(%<%= inspect scope.alias %>{} = scope, message) do
    key = scope.<%= Enum.join(scope.access_path, ".") %>

    Phoenix.PubSub.broadcast(<%= inspect context.base_module %>.PubSub, "<%= scope.name %>:#{key}:<%= schema.plural %>", message)
  end

  @doc """
  Returns the list of <%= schema.plural %>.

  ## Examples

      iex> list_<%= schema.plural %>(scope)
      [%<%= inspect schema.alias %>{}, ...]

  """
  def list_<%= schema.plural %>(%<%= inspect scope.alias %>{} = scope) do
    Repo.all_by(<%= inspect schema.alias %>, <%= scope.schema_key %>: scope.<%= Enum.join(scope.access_path, ".") %>)
  end

  @doc """
  Gets a single <%= schema.singular %>.

  Raises `Ecto.NoResultsError` if the <%= schema.human_singular %> does not exist.

  ## Examples

      iex> get_<%= schema.singular %>!(scope, 123)
      %<%= inspect schema.alias %>{}

      iex> get_<%= schema.singular %>!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_<%= schema.singular %>!(%<%= inspect scope.alias %>{} = scope, <%= primary_key %>) do
    Repo.get_by!(<%= inspect schema.alias %>, <%= primary_key %>: <%= primary_key %>, <%= scope.schema_key %>: scope.<%= Enum.join(scope.access_path, ".") %>)
  end

  @doc """
  Creates a <%= schema.singular %>.

  ## Examples

      iex> create_<%= schema.singular %>(scope, %{field: value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> create_<%= schema.singular %>(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_<%= schema.singular %>(%<%= inspect scope.alias %>{} = scope, attrs) do
    with {:ok, <%= schema.singular %> = %<%= inspect schema.alias %>{}} <-
           %<%= inspect schema.alias %>{}
           |> <%= inspect schema.alias %>.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_<%= schema.singular %>(scope, {:created, <%= schema.singular %>})
      {:ok, <%= schema.singular %>}
    end
  end

  @doc """
  Updates a <%= schema.singular %>.

  ## Examples

      iex> update_<%= schema.singular %>(scope, <%= schema.singular %>, %{field: new_value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> update_<%= schema.singular %>(scope, <%= schema.singular %>, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_<%= schema.singular %>(%<%= inspect scope.alias %>{} = scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs) do
    true = <%= schema.singular %>.<%= scope.schema_key %> == scope.<%= Enum.join(scope.access_path, ".") %>

    with {:ok, <%= schema.singular %> = %<%= inspect schema.alias %>{}} <-
           <%= schema.singular %>
           |> <%= inspect schema.alias %>.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_<%= schema.singular %>(scope, {:updated, <%= schema.singular %>})
      {:ok, <%= schema.singular %>}
    end
  end

  @doc """
  Deletes a <%= schema.singular %>.

  ## Examples

      iex> delete_<%= schema.singular %>(scope, <%= schema.singular %>)
      {:ok, %<%= inspect schema.alias %>{}}

      iex> delete_<%= schema.singular %>(scope, <%= schema.singular %>)
      {:error, %Ecto.Changeset{}}

  """
  def delete_<%= schema.singular %>(%<%= inspect scope.alias %>{} = scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>) do
    true = <%= schema.singular %>.<%= scope.schema_key %> == scope.<%= Enum.join(scope.access_path, ".") %>

    with {:ok, <%= schema.singular %> = %<%= inspect schema.alias %>{}} <-
           Repo.delete(<%= schema.singular %>) do
      broadcast_<%= schema.singular %>(scope, {:deleted, <%= schema.singular %>})
      {:ok, <%= schema.singular %>}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking <%= schema.singular %> changes.

  ## Examples

      iex> change_<%= schema.singular %>(scope, <%= schema.singular %>)
      %Ecto.Changeset{data: %<%= inspect schema.alias %>{}}

  """
  def change_<%= schema.singular %>(%<%= inspect scope.alias %>{} = scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs \\ %{}) do
    true = <%= schema.singular %>.<%= scope.schema_key %> == scope.<%= Enum.join(scope.access_path, ".") %>

    <%= inspect schema.alias %>.changeset(<%= schema.singular %>, attrs, scope)
  end
