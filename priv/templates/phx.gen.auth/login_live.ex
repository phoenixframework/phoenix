defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Login do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} <%= scope_config.scope.assign_key %>={@<%= scope_config.scope.assign_key %>}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%%= if @<%= scope_config.scope.assign_key %> do %>
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
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"<%= schema.route_prefix %>/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@<%= scope_config.scope.assign_key %>}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="divider">or</div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"<%= schema.route_prefix %>/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@<%= scope_config.scope.assign_key %>}
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
          <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button class="btn btn-primary btn-soft w-full mt-2">
            Log in only this time
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:<%= scope_config.scope.assign_key %>, Access.key(:<%= schema.singular %>), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "<%= schema.singular %>")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
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
