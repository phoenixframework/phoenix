defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationInstructionsLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  def render(assigns) do
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

  def mount(_params, _session, socket) do
    {:ok, socket}
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
