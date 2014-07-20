defmodule Phoenix.Controller.Errors do

  defmodule UnfetchedContentType do

    @moduledoc """
    Raised when trying to access private conn :phoenix_content_type when it
    has yet to be fetched
    """
    defexception [:message]
    def exception(msg) do
      %UnfetchedContentType {message: inspect(msg)}
    end
  end

end
