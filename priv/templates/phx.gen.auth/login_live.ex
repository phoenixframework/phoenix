defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Login do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        <p>Log in</p>
        <:subtitle>
          <%%= if @current_<%= schema.singular %> do %>
            You need to reauthenticate to perform sensitive actions on your account.
          <%% else %>
            Don't have an account? <.link
              navigate={~p"<%= schema.route_prefix %>/register"}
              class="font-semibold text-brand hover:underline"
              phx-no-format
            >Sign up</.link> for an account now.
          <%% end %>
        </:subtitle>
      </.header>

      <.simple_form
        :let={f}
        for={@form}
        id="login_form_magic"
        action={~p"<%= schema.route_prefix %>/log-in"}
        phx-submit="submit_magic"
      >
        <.input
          readonly={!!@current_<%= schema.singular %>}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.button class="w-full">
          Log in with email <span aria-hidden="true">→</span>
        </.button>
      </.simple_form>

      <div class="flex items-center mt-8 -mb-6 text-sm">
        <hr class="flex-grow border-t-2 border-gray-300" />
        <span class="mx-2 text-gray-500">or</span>
        <hr class="flex-grow border-t-2 border-gray-300" />
      </div>

      <.simple_form
        :let={f}
        for={@form}
        id="login_form_password"
        action={~p"<%= schema.route_prefix %>/log-in"}
        phx-submit="submit_password"
        phx-trigger-action={@trigger_submit}
      >
        <.input
          readonly={!!@current_<%= schema.singular %>}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.input
          field={@form[:password]}
          type="password"
          label="Password"
          autocomplete="current-password"
        />
        <.input
          :if={!@current_<%= schema.singular %>}
          field={f[:remember_me]}
          type="checkbox"
          label="Keep me logged in"
        />
        <.button class="w-full">
          Log in <span aria-hidden="true">→</span>
        </.button>
      </.simple_form>

      <div :if={local_mail_adapter?()} class="mt-8 p-4 border text-center">
        <p>You are running the local mail adapter.</p>
        <p>
          To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_<%= schema.singular %>, Access.key(:email)])

    form = to_form(%{"email" => email}, as: "<%= schema.singular %>")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"<%= schema.singular %>" => %{"email" => email}}, socket) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(email) do
      <%= inspect context.alias %>.deliver_login_instructions(
        <%= schema.singular %>,
        &url(~p"<%= schema.route_prefix %>/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"<%= schema.route_prefix %>/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:<%= Mix.Phoenix.otp_app() %>, <%= inspect context.base_module %>.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
