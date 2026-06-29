
  alias <%= inspect schema.module %>
  alias <%= inspect scope.alias %>

  @doc """
  Subscribes to scoped notifications about any <%= schema.singular %> changes.
  """
  def subscribe_<%= schema.singular %>(%<%= inspect scope.alias %>{} = _scope) do
    raise "TODO"
  end

  @doc """
  Returns the list of <%= schema.plural %>.

  ## Examples

      iex> list_<%= schema.plural %>(scope)
      [%<%= inspect schema.alias %>{}, ...]

  """
  def list_<%= schema.plural %>(%<%= inspect scope.alias %>{} = _scope) do
    raise "TODO"
  end

  @doc """
  Gets a single <%= schema.singular %>.

  Raises if the <%= schema.human_singular %> does not exist.

  ## Examples

      iex> get_<%= schema.singular %>!(scope, 123)
      %<%= inspect schema.alias %>{}

  """
  def get_<%= schema.singular %>!(%<%= inspect scope.alias %>{} = _scope, id), do: raise "TODO"

  @doc """
  Creates a <%= schema.singular %>.

  ## Examples

      iex> create_<%= schema.singular %>(scope, %{field: value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> create_<%= schema.singular %>(scope, %{field: bad_value})
      {:error, ...}

  """
  def create_<%= schema.singular %>(%<%= inspect scope.alias %>{} = _scope, attrs) do
    raise "TODO"
  end

  @doc """
  Updates a <%= schema.singular %>.

  ## Examples

      iex> update_<%= schema.singular %>(scope, <%= schema.singular %>, %{field: new_value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> update_<%= schema.singular %>(scope, <%= schema.singular %>, %{field: bad_value})
      {:error, ...}

  """
  def update_<%= schema.singular %>(%<%= inspect scope.alias %>{} = _scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a <%= inspect schema.alias %>.

  ## Examples

      iex> delete_<%= schema.singular %>(scope, <%= schema.singular %>)
      {:ok, %<%= inspect schema.alias %>{}}

      iex> delete_<%= schema.singular %>(scope, <%= schema.singular %>)
      {:error, ...}

  """
  def delete_<%= schema.singular %>(%<%= inspect scope.alias %>{} = _scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>) do
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking <%= schema.singular %> changes.

  ## Examples

      iex> change_<%= schema.singular %>(scope, <%= schema.singular %>)
      %Todo{...}

  """
  def change_<%= schema.singular %>(%<%= inspect scope.alias %>{} = _scope, %<%= inspect schema.alias %>{} = <%= schema.singular %>, _attrs \\ %{}) do
    raise "TODO"
  end
