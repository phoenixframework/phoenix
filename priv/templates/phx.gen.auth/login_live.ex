defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LoginLive do
  use <%= inspect context.web_module %>, :live_view

  def render(assigns) do
    ~H"""
    <h1>Log in</h1>

    <.form
      id="login_form"
      :let={f}
      for={:<%= schema.singular %>}
      phx-change="validate"
      action={Routes.<%= schema.route_helper %>_session_path(@socket, :login)}
      as={:<%= schema.singular %>}
    >
      <%%= if @error_message do %>
        <div class="alert alert-danger">
        <p><%%= @error_message %></p>
        </div>
      <%% end %>

      <%%= label f, :email %>
      <%%= email_input f, :email, required: true, value: @email %>

      <%%= label f, :password %>
      <%%= password_input f, :password, required: true, value: @password %>

      <%%= label f, :remember_me, "Keep me logged in for 60 days" %>
      <%%= checkbox f, :remember_me, value: @remember_me %>

      <div>
        <%%= submit "Log in" %>
      </div>
    </.form>

    <p>
      <.link href={Routes.<%= schema.route_helper %>_registration_path(@socket, :new)}>Register</.link> |
      <.link href={Routes.<%= schema.route_helper %>_reset_password_path(@socket, :new)}>Forgot your password?</.link>
    </p>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       error_message: nil,
       password: nil,
       email: nil,
       remember_me: false
     )}
  end

  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    %{"email" => email, "password" => password, "remember_me" => remember_me} = <%= schema.singular %>_params

    {:noreply,
     assign(socket,
       password: password,
       email: email,
       remember_me: remember_me
     )}
  end
end
