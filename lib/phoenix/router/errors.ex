defmodule Phoenix.Router.Errors do

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
