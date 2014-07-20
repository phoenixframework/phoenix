defmodule Phoenix.Router.Errors do

  @doc """
  Ensure path given to router macros is valid and begins with "/"
  raises `ArgumentError` when invalid
  """
  def ensure_valid_path!(<<"/" <> _rest>>), do: nil
  def ensure_valid_path!(path) do
    raise ArgumentError, message: """
    Path must start with slash.
    Change path from:
    #{path}
    to
    /#{path}
    """
  end
end
