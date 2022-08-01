defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  on_mount {<%= inspect auth_module %>, :mount_current_<%= schema.singular %>}

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <h1>Confirm account</h1>

    <.form id="confirmation_form" :let={f} for={:<%= schema.singular %>} phx-submit="confirm_account"}>
      <div>
        <%%= hidden_input f, :token, value: @token %>
        <%%= submit "Confirm my account" %>
      </div>
    </.form>

    <p>
      <.link href={Routes.<%= schema.route_helper %>_registration_path(@socket, :new)}>Register</.link> |
      <.link href={Routes.<%= schema.route_helper %>_login_path(@socket, :new)}>Log in</.link>
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
          |> put_flash(:info, "User confirmed successfully.")
          |> redirect(to: "/")}

      :error ->
        # If there is a current <%= schema.singular %> and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the <%= schema.singular %> themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_<%= schema.singular %>: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: "/")}

          %{} ->
            {:noreply,
              socket
              |> put_flash(:error, "User confirmation link is invalid or it has expired.")
              |> redirect(to: "/")}
        end
    end
  end
end
