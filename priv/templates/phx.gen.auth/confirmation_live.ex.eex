defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Confirmation do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} <%= scope_config.scope.assign_key %>={@<%= scope_config.scope.assign_key %>}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>Welcome {@<%= schema.singular %>.email}</.header>
        </div>

        <.form
          :if={!@<%= schema.singular %>.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"<%= schema.route_prefix %>/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Confirming..."
            class="btn btn-primary w-full"
          >
            Confirm and stay logged in
          </.button>
          <.button phx-disable-with="Confirming..." class="btn btn-primary btn-soft w-full mt-2">
            Confirm and log in only this time
          </.button>
        </.form>

        <.form
          :if={@<%= schema.singular %>.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"<%= schema.route_prefix %>/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%%= if @<%= scope_config.scope.assign_key %> do %>
            <.button phx-disable-with="Logging in..." class="btn btn-primary w-full">
              Log in
            </.button>
          <%% else %>
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Logging in..."
              class="btn btn-primary w-full"
            >
              Keep me logged in on this device
            </.button>
            <.button phx-disable-with="Logging in..." class="btn btn-primary btn-soft w-full mt-2">
              Log me in only this time
            </.button>
          <%% end %>
        </.form>

        <p :if={!@<%= schema.singular %>.confirmed_at} class="alert alert-outline mt-8">
          Tip: If you prefer passwords, you can enable them in the <%= schema.singular %> settings.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "<%= schema.singular %>")

      {:ok, assign(socket, <%= schema.singular %>: <%= schema.singular %>, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"<%= schema.route_prefix %>/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"<%= schema.singular %>" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "<%= schema.singular %>"), trigger_submit: true)}
  end
end
