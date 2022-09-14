defmodule <%= @web_namespace %>.Components do
  @moduledoc """
  Provides core UI components.

  The components in this module use tailwindcss, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn how to
  customize the generated components in this module.
  """
  use Phoenix.Component

  <%= if @gettext do %>import <%= @web_namespace %>.Gettext, warn: false
  <% end %>
  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        Are you sure you?
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:confirm>
      <.modal>

  JS commands may be passed to the `:on_cancel` and `on_confirm` attributes
  for the caller to reactor to each button press, for example:

      <.modal id="confirm" on_confirm={JS.push("delete")} on_cancel={JS.navigate(~p"/posts")}>
        Are you sure you?
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:confirm>
      <.modal>
  """

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, JS, default: %JS{}
  attr :rest, :global

  slot :inner_block, required: true
  slot :title
  slot :subtitle

  slot :confirm do
    attr :if, :boolean
  end

  slot :cancel do
    attr :if, :boolean
  end

  def modal(assigns) do
    ~H"""
    <div id={@id} phx-mounted={@show && show_modal(@id)} class="relative z-50 hidden" {@rest}>
      <div
        id={"#{@id}-backdrop"}
        class="fixed inset-0 bg-zinc-50/90 transition-opacity"
        aria-hidden="true"
      >
      </div>
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-mounted={@show && show_modal(@id)}
              phx-window-keydown={hide_modal(@on_cancel, @id)}
              phx-key="escape"
              phx-click-away={hide_modal(@on_cancel, @id)}
              class="hidden relative rounded-2xl bg-white p-14 shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition"
            >
              <div class="absolute top-6 right-6">
                <button
                  type="button"
                  phx-click={hide_modal(@on_cancel, @id)}
                  class="group -m-3 flex-none p-3"
                  aria-label="Close"
                >
                  <svg
                    viewBox="0 0 12 12"
                    aria-hidden="true"
                    class="h-3 w-3 stroke-zinc-300 group-hover:stroke-zinc-400"
                  >
                    <path d="M1 1L11 11M11 1L1 11" stroke-width="2" stroke-linecap="round" />
                  </svg>
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%%= if @title != [] do %>
                  <header>
                    <h1 id={"#{@id}-title"} class="text-lg font-semibold leading-8 text-zinc-800">
                      <%%= render_slot(@title) %>
                    </h1>
                    <%%= if @subtitle != [] do %>
                      <p class="mt-2 text-sm leading-6 text-zinc-600">
                        <%%= render_slot(@subtitle) %>
                      </p>
                    <%% end %>
                  </header>
                <%% end %>
                <%%= render_slot(@inner_block) %>
                <%%= if @confirm != [] or @cancel != [] do %>
                  <div class="ml-6 mb-4 flex items-center gap-5">
                    <%%= for confirm <- @confirm, Map.get(confirm, :if, true) do %>
                      <.button
                        id={"#{@id}-confirm"}
                        class="rounded-lg bg-zinc-900 py-2 px-3 text-sm font-semibold leading-6 text-white hover:bg-zinc-700 active:text-white/80"
                        phx-click={@on_confirm}
                        phx-disable-with
                        {assigns_to_attributes(confirm, [:if])}
                      >
                        <%%= render_slot(confirm) %>
                      </.button>
                    <%% end %>
                    <%%= for cancel <- @cancel, Map.get(cancel, :if, true) do %>
                      <.link
                        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                        phx-click={hide_modal(@on_cancel, @id)}
                        {assigns_to_attributes(cancel, [:if])}
                      >
                        <%%= render_slot(cancel) %>
                      </.link>
                    <%% end %>
                  </div>
                <%% end %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  slot :connected
  slot :disconnected
  slot :loading

  def connection(assigns) do
    ~H"""
    <div id="connection-status">
      <div class="hidden phx-connected:block"><%%= render_slot(@connected) %></div>
      <div class="hidden phx-error:block"><%%= render_slot(@disconnected) %></div>
      <div class="hidden phx-loading:block"><%%= render_slot(@loading) %></div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={get_flash(@conn)} />
      <.flash kind={:info} message="Welcome back!" />
  """
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :message, :string, default: nil, doc: "directly displays a message"
  attr :kind, :atom, doc: "one of :info, :error used for styling and flash lookup"
  attr :animate, :boolean, default: true, doc: "animates in the flash"

  def flash(assigns) do
    ~H"""
    <%%= if msg = @message || @flash[to_string(@kind)] do %>
      <div
        id="flash"
        phx-mounted={show("#flash")}
        phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("#flash")}
        class={
          [
            "fixed top-2 right-2 w-96 z-50 rounded-lg p-3 shadow-md shadow-zinc-900/5 ring-1",
            @animate && "hidden",
            @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500",
            @kind == :error && "bg-rose-50 p-3 text-rose-900 shadow-md ring-rose-500"
          ]
        }
      >
        <button type="button" class="group absolute top-2 right-1 p-2" aria-label="Close">
          <svg
            viewBox="0 0 16 16"
            fill="none"
            aria-hidden="true"
            class={
              [
                "h-4 w-4",
                @kind == :info && "stroke-emerald-900/40 group-hover:stroke-emerald-900/60",
                @kind == :error && "stroke-rose-900/20 group-hover:stroke-rose-900/40"
              ]
            }
          >
            <path d="m3 3 10 10m0-10L3 13" stroke-width="2" stroke-linecap="round"></path>
          </svg>
        </button>
        <p class="flex items-center gap-1.5 text-[0.8125rem] font-semibold leading-6">
          <svg
            viewBox="0 0 20 20"
            aria-hidden="true"
            class={
              [
                "h-5 w-5 flex-none",
                @kind == :info && "fill-cyan-900",
                @kind == :error && "fill-rose-900"
              ]
            }
          >
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M10 17a7 7 0 1 0 0-14 7 7 0 0 0 0 14Zm1-9a1 1 0 1 1-2 0 1 1 0 0 1 2 0Zm-2 3a1 1 0 1 1 2 0v1a1 1 0 1 1-2 0v-1Z"
            >
            </path>
          </svg>
          <%%= if @kind == :info do %>
            Success!
          <%% end %>
          <%%= if @kind == :error do %>
            Error!
          <%% end %>
        </p>
        <p class="mt-2 text-[0.8125rem] leading-5"><%%= msg %></p>
      </div>
    <%% end %>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form :let={f} for={:user} phx-change="validate" phx-submit="save">
        <.input field={{f, :email}} label="Email"/>
        <.input field={{f, :username}} label="Username" />
        <:actions>
          <.button>Save</.button>
        <:actions>
      </.simple_form>
  """

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  attr :for, :any, default: nil, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  attr :rest, :global, doc: "the arbitraty HTML attributes to apply to the form tag"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-8 bg-white mt-10">
        <%%= render_slot(@inner_block, f) %>
        <%%= for action <- @actions do %>
          <div class="mt-2 flex items-center justify-between gap-6">
            <%%= render_slot(action, f) %>
          </div>
        <%% end %>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button class="abc">Send!</.button>
  """

  slot :inner_block, required: true
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, doc: "the arbitraty HTML attributes to apply to the button tag"

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={
        [
          "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 py-2 px-3 text-sm font-semibold leading-6 text-white hover:bg-zinc-700 active:text-white/80",
          @class
        ]
      }
      {@rest}
    >
      <%%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `%Phoenix.HTML.Form{}` and field name may be passed to the input
  to build input names and error messages, or all the attributes and
  errors may be passed explicitly.

  ## Examples

      <.input field={{f, :email}} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  slot :inner_block
  attr :id, :any
  attr :name, :any
  attr :label, :string, default: nil

  attr :type, :string,
    default: "text",
    doc: ~s|one of "text", "textarea", "number" "email", "date", "time", "datetime", "select"|

  attr :value, :any
  attr :field, :any, doc: "a %Phoenix.HTML.Form{}/field name tuple, for example: {f, :email}"
  attr :errors, :list
  attr :rest, :global

  def input(%{field: {f, field}} = assigns) do
    assigns
    |> assign(:field, nil)
    |> assign_new(:name, fn -> Phoenix.HTML.Form.input_name(f, field) end)
    |> assign_new(:id, fn -> Phoenix.HTML.Form.input_id(f, field) end)
    |> assign_new(:value, fn -> Phoenix.HTML.Form.input_value(f, field) end)
    |> assign_new(:errors, fn ->
      Enum.map(Keyword.get_values(f.errors || [], field), &translate_error(&1))
    end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    ~H"""
    <label phx-feedback-for={@name} class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
      <input
        type="checkbox"
        id={@id || @name}
        name={@name}
        class="rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900"
      />
      <%%= @label %>
    </label>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-semibold leading-6 text-zinc-800">
        <%%= @label %>
      </label>
      <select
        id={@id}
        name={@name}
        autocomplete={@name}
        class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
        {@rest}
      >
        <%%= for opt <- @option do %>
          <option {assigns_to_attributes(opt)}><%%= render_slot(opt) %></option>
        <%% end %>
      </select>
      <%%= for error <- @errors do %>
        <.error message={error} class="phx-no-feedback:hidden" phx-feedback-for={@name} />
      <%% end %>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <label for={@id} class="block text-sm font-semibold leading-6 text-zinc-800">
        <%%= @label %>
      </label>
      <textarea
        id={@id || @name}
        name={@name}
        class={"#{input_border(@errors)} phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400 phx-no-feedback:focus:ring-zinc-800/5 mt-2 block min-h-[6rem] w-full rounded-lg border-zinc-300 py-[calc(theme(spacing.2)-1px)] px-[calc(theme(spacing.3)-1px)] text-zinc-900 focus:border-zinc-400 focus:outline-none focus:ring-4 focus:ring-zinc-800/5 sm:text-sm sm:leading-6"}
        {@rest}
      ><%%= @value %></textarea>
      <%%= for error <- @errors do %>
        <.error message={error} class="phx-no-feedback:hidden" />
      <%% end %>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <label for={@id} class="block text-sm font-semibold leading-6 text-zinc-800">
        <%%= @label %>
      </label>
      <input
        type={@type}
        name={@name}
        id={@id || @name}
        value={@value}
        class={"#{input_border(@errors)} phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400 phx-no-feedback:focus:ring-zinc-800/5 mt-2 block w-full rounded-lg border-zinc-300 py-[calc(theme(spacing.2)-1px)] px-[calc(theme(spacing.3)-1px)] text-zinc-900 focus:outline-none focus:ring-4 sm:text-sm sm:leading-6"}
        {@rest}
      />
      <%%= for error <- @errors do %>
        <.error message={error} class="phx-no-feedback:hidden" />
      <%% end %>
    </div>
    """
  end

  defp input_border([] = _errors),
    do: "border-zinc-300 focus:border-zinc-400 focus:ring-zinc-800/5"

  defp input_border([_ | _] = _errors),
    do: "border-rose-400 focus:border-rose-400 focus:ring-rose-400/10"

  @doc """
  Generates a generic error message.
  """
  attr :message, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def error(assigns) do
    ~H"""
    <p class={["mt-3 flex gap-3 text-sm leading-6 text-rose-600", @class]} {@rest}>
      <svg viewBox="0 0 20 20" aria-hidden="true" class="mt-0.5 h-5 w-5 flex-none fill-rose-500">
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M18 10a8 8 0 1 1-16.001 0A8 8 0 0 1 18 10Zm-7 4a1 1 0 1 1-2 0 1 1 0 0 1 2 0Zm-1-9a1 1 0 0 0-1 1v4a1 1 0 1 0 2 0V6a1 1 0 0 0-1-1Z"
        >
        </path>
      </svg>
      <%%= @message %>
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """

  slot :inner_block, required: true
  slot :subtitle
  slot :actions
  attr :centered, :boolean, default: false
  attr :class, :string, default: nil

  def header(%{actions: []} = assigns) do
    ~H"""
    <header class={@class}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
          <%%= render_slot(@inner_block) %>
        </h1>
        <%%= if @subtitle != [] do %>
          <p class="mt-2 text-sm leading-6 text-zinc-600"><%%= render_slot(@subtitle) %></p>
        <%% end %>
      </div>
    </header>
    """
  end

  def header(assigns) do
    ~H"""
    <header class={["flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
          <%%= render_slot(@inner_block) %>
        </h1>
        <%%= if @subtitle != [] do %>
          <p class="mt-2 text-sm leading-6 text-zinc-600"><%%= render_slot(@subtitle) %></p>
        <%% end %>
      </div>
      <div class="flex-none">
        <%%= render_slot(@actions) %>
      </div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table rows={@users} row_id={&"user-#{&1.id}"}>
        <:title>Users</:title>
        <:subtitle>Active in the last 24 hours</:subtitle>
        <:col :let={user} label="id"><%%= user.id %></:col>
        <:col :let={user} label="username"><%%= user.username %></:col>
      </.table>
  """

  attr :id, :string, required: true
  attr :row_click, JS, default: nil
  attr :rows, :list, required: true

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    ~H"""
    <div id={@id} class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="mt-11 w-[40rem] sm:w-full">
        <thead class="text-left text-[0.8125rem] leading-6 text-zinc-500">
          <tr>
            <%%= for col <- @col do %>
              <th class="p-0 pb-4 pr-6 font-normal"><%%= col.label %></th>
            <%% end %>
            <th class="relative p-0 pb-4"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700">
          <%%= for row <- @rows, row_id = "#{@id}-row-#{Phoenix.Param.to_param(row)}" do %>
            <tr
              id={row_id}
              class="group hover:bg-zinc-50  hover:cursor-pointer"
              phx-click={@row_click && @row_click.(row)}
            >
              <%%= for {col, i} <- Enum.with_index(@col) do %>
                <td class={["relative p-0", col[:class]]}>
                  <div class="block py-4 pr-6">
                    <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl">
                    </span>
                    <span class={["relative", if(i == 0, do: "font-semibold text-zinc-900")]}>
                      <%%= render_slot(col, row) %>
                    </span>
                  </div>
                </td>
              <%% end %>
              <%%= if @action !=[] do %>
                <td class="relative p-0">
                  <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                    <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl">
                    </span>
                    <%%= for action <- @action do %>
                      <span class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700">
                        <%%= render_slot(action, row) %>
                      </span>
                    <%% end %>
                  </div>
                </td>
              <%% end %>
            </tr>
          <%% end %>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%%= @post.title %></:item>
        <:item title="Views"><%%= @post.views %></:item>
      </.list>
  """

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-zinc-100">
        <%%= for item <- @item do %>
          <div class="flex gap-4 py-4 sm:gap-8">
            <dt class="w-1/4 flex-none text-[0.8125rem] leading-6 text-zinc-500">
              <%%= item.title %>
            </dt>
            <dd class="text-sm leading-6 text-zinc-700"><%%= render_slot(item) %></dd>
          </div>
        <%% end %>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """

  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <span aria-hidden="true">&larr;</span>
        <%%= render_slot(@inner_block) %>
      </.link>
    </div>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 scale-95",
         "opacity-100 translate-y-0 scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-in duration-300", "opacity-100 scale-100",
         "opacity-0 scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-backdrop",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-backdrop",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.pop_focus()
  end<%= if @gettext do %>

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(<%= @web_namespace %>.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(<%= @web_namespace %>.Gettext, "errors", msg, opts)
    end
  end<% else %>

  @doc """
  Translates an error message.
  """
  def translate_error({msg, opts}) do
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end<% end %>
end
