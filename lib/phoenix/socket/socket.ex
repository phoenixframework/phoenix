defmodule Phoenix.Socket do
  defstruct conn: nil,
            pid: nil,
            router: nil,
            channels: [],
            assigns: []
end


