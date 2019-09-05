defmodule <%= module %> do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](http://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence, otp_app: <%= inspect otp_app %>,
                        pubsub_server: <%= inspect pubsub_server %>
end
