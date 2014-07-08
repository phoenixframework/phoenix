defmodule Phoenix.Controller.Errors do

  defmodule UnfetchedContentType do
    defexception [:message]
    def exception(msg) do
      %UnfetchedContentType {message: inspect(msg)}
    end
  end

end
