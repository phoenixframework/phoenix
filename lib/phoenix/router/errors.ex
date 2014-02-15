defmodule Phoenix.Router.Errors do

  def ensure_valid_path!(path) do
    message = """
    Path must start with slash.
    Change path from:
    #{path}
    to
    /#{path}
    """

    unless String.at(path, 0) == "/" do
      raise(ArgumentError, message: message)
    end
  end

end
