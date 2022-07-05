defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  on_mount {<%= inspect auth_module %>, :mount_current_<%= schema.singular %>}

  def render(%{live_action: :new} = assigns) do
    ~H"""
    <h1>Resend confirmation instructions</h1>

    <.form id="resend_confirmation_form" :let={f} for={:<%= schema.singular %>} phx-submit="send_instructions">
      <%%= label f, :email %>
      <%%= email_input f, :email, required: true %>

      <div>
        <%%= submit "Resend confirmation instructions" %>
      </div>
    </.form>

    <p>
      <.link href={Routes.<%= schema.route_helper %>_registration_path(@socket, :new)}>Register</.link> |
      <.link href={Routes.<%= schema.route_helper %>_login_path(@socket, :new)}>Log in</.link>
    </p>
    """
  end

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <h1>Confirm account</h1>

    <.form id="confirmation_form" :let={_f} for={:<%= schema.singular %>} phx-submit="confirm_account"}>
      <div>
        <%%= submit "Confirm my account" %>
      </div>
    </.form>

    <p>
      <.link href={Routes.<%= schema.route_helper %>_registration_path(@socket, :new)}>Register</.link> |
      <.link href={Routes.<%= schema.route_helper %>_login_path(@socket, :new)}>Log in</.link>
    </p>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"token" => token}, _uri, socket),
    do: {:noreply, assign(socket, :token, token)}

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # Do not log in the <%= schema.singular %> after confirmation to avoid a
  # leaked token giving the <%= schema.singular %> access to the account.
  def handle_event("confirm_account", _params, socket) do
    case <%= inspect context.alias %>.confirm_<%= schema.singular %>(socket.assigns.token) do
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

  def handle_event("send_instructions", %{"<%= schema.singular %>" => %{"email" => email}}, socket) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(email) do
      <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(
        <%= schema.singular %>,
        &Routes.<%= schema.route_helper %>_confirmation_url(socket, :edit, &1)
      )
    end

    info = "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: "/")}
  end
end
