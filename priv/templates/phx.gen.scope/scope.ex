defmodule <%= inspect(scope.module) %> do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `<%= inspect(scope.module) %>` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  defstruct current_user: nil, current_user_id: nil, peer_ip: nil

  def for_user(current_user_or_nil, _session \\ %{}, _peer_data \\ %{})

  def for_user(nil, %{} = _session, %{} = peer_data) do
    %__MODULE__{current_user: nil, current_user_id: nil, peer_ip: peer_ip(peer_data)}
  end

  def for_user(%{} = user, %{} = _session, %{} = peer_data) do
    %__MODULE__{
      current_user: user,
      current_user_id: user.id,
      peer_ip: peer_ip(peer_data)
    }
  end

  defp peer_ip(%{address: addr} = _peer_data), do: addr
  defp peer_ip(_), do: nil
end
