defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <.header>Confirm Account</.header>

    <.simple_form :let={f} for={:<%= schema.singular %>} id="confirmation_form" phx-submit="confirm_account">
      <.input field={{f, :token}} type="hidden" value={@token} />
      <:actions>
        <.button phx-disable-with="Confirming...">Confirm my account</.button>
      </:actions>
    </.simple_form>

    <p>
      <.link href={~p"<%= schema.route_prefix %>/register"}>Register</.link>
      |
      <.link href={~p"<%= schema.route_prefix %>/log_in"}>Log in</.link>
    </p>
    """
  end

  def mount(params, _session, socket) do
    {:ok, assign(socket, token: params["token"]), temporary_assigns: [token: nil]}
  end

  # Do not log in the <%= schema.singular %> after confirmation to avoid a
  # leaked token giving the <%= schema.singular %> access to the account.
  def handle_event("confirm_account", %{"<%= schema.singular %>" => %{"token" => token}}, socket) do
    case <%= inspect context.alias %>.confirm_<%= schema.singular %>(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "<%= inspect schema.alias %> confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current <%= schema.singular %> and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the <%= schema.singular %> themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_<%= schema.singular %>: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "<%= inspect schema.alias %> confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
