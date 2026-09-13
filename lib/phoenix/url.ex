defmodule Phoenix.URL do
  @moduledoc false

  # Characters a browser's URL parser removes or reinterprets, which would let
  # a path that looks local here resolve to another origin once parsed.
  #
  # `\n` and `\r` are matched anywhere on purpose: with those rejected outright,
  # the only remaining parser-stripped character is the tab, so a leading `/`
  # can only reach a second `/` through tabs and `"/\t"` is enough to catch it.
  # Listing them positionally would allow `"/\n\t/example.com"`.
  @invalid_local_url_chars ["\\", "/%09", "/\t", "\n", "\r"]

  @doc """
  Classifies `path` as a local path that is safe to hand to a browser.

  Returns `:ok`, `{:error, :invalid}` when it is not a path at all or is
  already scheme-relative, or `{:error, :unsafe}` when it carries characters
  that would change the origin once parsed.
  """
  def classify_local_path("//" <> _), do: {:error, :invalid}

  def classify_local_path("/" <> _ = path) do
    if String.contains?(path, @invalid_local_url_chars) do
      {:error, :unsafe}
    else
      :ok
    end
  end

  def classify_local_path(_path), do: {:error, :invalid}

  @doc """
  Returns `path` if it is a safe local path, raises otherwise.
  """
  def validate_local_path!(path) do
    case classify_local_path(path) do
      :ok ->
        path

      {:error, :invalid} ->
        raise ArgumentError, "expected a path starting with a single / but got #{inspect(path)}"

      {:error, :unsafe} ->
        raise ArgumentError, "unsafe characters detected for path #{inspect(path)}"
    end
  end
end
