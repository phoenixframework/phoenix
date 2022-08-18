defmodule <%= @web_namespace %>.Components do
  @moduledoc """
  Provides core UI components.

  *Note*: The `modal`, `flash`, `table`, `button`, `hero`, `simple_form`, and `input`
  function components are derived from Tailwind UI, with explicit permission
  granted to the `phx.new` generator. Visit [Tailwind UI](https://tailwindui.com)
  for comprehensive components, or the [Tailwind CSS documentation](https://tailwindcss.com)
  to learn how to customize the generated components in this module.
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

      <.modal id="confirm-modal" on_confirm={JS.push("delete-item")}>
        Are you sure you?
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:confirm>
      <.modal>

  Live navigation on close/cancel is supported via the `:navigate` and `:patch` attributes:

      <.modal id="modal" navigate={~p"/posts"}>...
  """

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :patch, :string, default: nil
  attr :navigate, :string, default: nil
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, JS, default: %JS{}
  attr :rest, :global

  slot :inner_block, required: true
  slot :title
  slot :confirm
  slot :cancel

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show(@id)}
      class="fixed z-10 inset-0 overflow-y-auto hidden"
      {@rest}
    >
      <div
        class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true">
        </div>
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>
        <.focus_wrap
          id={"#{@id}-container"}
          phx-mounted={@show && show_modal(@id)}
          phx-window-keydown={hide_modal(@on_cancel, @id)}
          phx-key="escape"
          phx-click-away={hide_modal(@on_cancel, @id)}
          class="hidden sticky inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform sm:my-8 sm:align-middle sm:max-w-xl sm:w-full sm:p-6"
        >
          <%%= if @patch do %>
            <.link patch={@patch} data-modal-return class="hidden"></.link>
          <%% end %>
          <%%= if @navigate do %>
            <.link navigate={@navigate} data-modal-return class="hidden"></.link>
          <%% end %>
          <div class={"sm:flex sm:items-start #{if @confirm == [] && @cancel == [], do: "pt-3"}"}>
            <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-indigo-100 sm:mx-0 sm:h-10 sm:w-10">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-indigo-500"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full mr-12">
              <h3 class="text-lg leading-6 font-medium text-gray-900" id={"#{@id}-title"}>
                <%%= render_slot(@title) %>
              </h3>
              <div class="mt-2">
                <p id={"#{@id}-content"} class="text-md text-gray-500">
                  <%%= render_slot(@inner_block) %>
                </p>
              </div>
            </div>
          </div>
          <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
            <%%= for confirm <- @confirm do %>
              <.button
                primary
                id={"#{@id}-confirm"}
                class="w-full text-base text-base sm:ml-3 sm:w-auto sm:text-sm"
                phx-click={@on_confirm}
                phx-disable-with
                {assigns_to_attributes(confirm)}
              >
                <%%= render_slot(confirm) %>
              </.button>
            <%% end %>
            <%%= for cancel <- @cancel do %>
              <button
                class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm"
                phx-click={hide_modal(@on_cancel, @id)}
                {assigns_to_attributes(cancel)}
              >
                <%%= render_slot(cancel) %>
              </button>
            <%% end %>
          </div>
        </.focus_wrap>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash}/>
      <.flash kind={:error} flash={get_flash(@conn)}/>
  """
  attr :flash, :map
  attr :kind, :atom, doc: "one of :info, :error"
  attr :animate, :boolean, default: true, doc: "animates in the flash"

  def flash(%{kind: :error} = assigns) do
    ~H"""
    <%%= if @flash[to_string(@kind)] do %>
      <div
        id="flash"
        class={"#{@animate && "hidden"} rounded-md bg-red-50 p-4 fixed top-1 right-1 w-96 z-50 shadow shadow-red-200"}
        phx-mounted={show("#flash")}
        phx-click={JS.push("lv:clear-flash") |> hide("#flash")}
      >
        <div class="flex justify-between items-center space-x-3 pl-2 text-red-700">
          <p class="flex-1 text-sm font-medium" role="alert">
            <%%= @flash[to_string(@kind)] %>
          </p>
          <button
            type="button"
            class="inline-flex bg-red-50 rounded-md p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-red-50 focus:ring-red-600"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </button>
        </div>
      </div>
    <%% end %>
    """
  end

  def flash(%{kind: :info} = assigns) do
    ~H"""
    <%%= if @flash[to_string(@kind)] do %>
      <div
        id="flash"
        class={"#{@animate && "hidden"} rounded-md bg-green-50 p-4 fixed top-2 right-2 w-96 z-50 shadow shadow-green-200"}
        phx-mounted={show("#flash")}
        phx-click={JS.push("lv:clear-flash") |> hide("#flash")}
        phx-value-key="info"
      >
        <div class="flex justify-between items-center space-x-3 text-green-700 pl-2">
          <p class="flex-1 text-sm font-medium" role="alert">
            <%%= @flash[to_string(@kind)] %>
          </p>
          <button
            type="button"
            class="inline-flex bg-green-50 rounded-md p-1.5 text-green-600 hover:bg-green-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-green-50 focus:ring-green-600"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </button>
        </div>
      </div>
    <%% end %>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form :let={f} for={:user} phx-change="validate" phx-submit="save">
        <:title>Profile</:title>
        <:subtitle>This information will be displayed publicly.</:subtitle>

        <.input field={{f, :email}} label="Email"/>
        <.input field={{f, :username}} label="Username" />

        <:confirm>Save</:confirm>
        <:cancel>Cancel</:cancel>
      </.simple_form>
  """

  slot :inner_block, required: true
  slot :title
  slot :subtitle
  slot :cancel
  slot :confirm
  attr :for, :any, default: nil
  attr :rest, :global

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} {@rest}>
      <div class="overflow-hidden">
        <div class="px-4 py-5 bg-white sm:p-6 grid grid-cols-4 gap-y-4">
          <%%= if @title || @subtitle do %>
            <div class="col-span-full mb-3">
              <%%= if @title do %>
                <h3 class="text-lg leading-6 font-medium text-gray-900">
                  <%%= render_slot(@title) %>
                </h3>
              <%% end %>
              <%%= if @subtitle do %>
                <p class="mt-1 text-sm text-gray-500"><%%= render_slot(@subtitle) %></p>
              <%% end %>
            </div>
          <%% end %>

          <%%= render_slot(@inner_block, f) %>

          <div class="mt-2 flex justify-end col-span-full">
            <%%= if @cancel do %>
              <.button type="button"><%%= render_slot(@cancel) %></.button>
            <%% end %>
            <%%= if @confirm do %>
              <.button type="submit" primary class="ml-3"><%%= render_slot(@confirm) %></.button>
            <%% end %>
          </div>
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button primary>Send!</.button>
      <.button class="abc">Send!</.button>
  """

  slot :inner_block, required: true
  attr :type, :string, default: "button"
  attr :primary, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def button(%{primary: false} = assigns) do
    ~H"""
    <button
      type={@type}
      class={
        [
          "phx-submit-loading:opacity-75 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 text-base font-medium bg-white text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm",
          @class
        ]
      }
      {@rest}
    >
      <%%= render_slot(@inner_block) %>
    </button>
    """
  end

  def button(%{primary: true} = assigns) do
    ~H"""
    <button
      type={@type}
      class={
        [
          "phx-submit-loading:opacity-75 w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 text-base font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm",
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
    doc: ~s|one of "text", "number" "email", "date", "time", "datetime", "select"|

  attr :value, :any
  attr :field, :any, doc: "a %Phoenix.HTML.Form{}/field name tuple, for example: {f, :email}"
  attr :errors, :list
  attr :class, :string, default: nil
  attr :rest, :global

  def input(%{field: {f, field}} = assigns) do
    assigns
    |> assign(:field, nil)
    |> assign_new(:name, fn -> Phoenix.HTML.Form.input_name(f, field) end)
    |> assign_new(:id, fn -> Phoenix.HTML.Form.input_id(f, field) end)
    |> assign_new(:value, fn -> Phoenix.HTML.Form.input_value(f, field) end)
    |> assign_new(:errors, fn ->
      Enum.map(Keyword.get_values(f.errors, field), &translate_error(&1))
    end)
    |> input()
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={["col-span-full", @class]}>
      <label for={@id} class="block text-sm font-medium text-gray-700">
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

  def input(assigns) do
    ~H"""
    <div class={["col-span-full", @class]} phx-feedback-for={@name}>
      <label for={@id} class="block text-sm font-medium text-gray-700">
        <%%= @label %>
      </label>
      <input
        type={@type}
        name={@name}
        id={@id || @name}
        value={@value}
        class={"#{input_border(@errors)} mt-1 block w-full shadow-sm sm:text-sm rounded-md phx-no-feedback:border-gray-300 phx-no-feedback:focus:ring-indigo-500"}
        {@rest}
      />
      <%%= for error <- @errors do %>
        <.error message={error} class="phx-no-feedback:hidden" />
      <%% end %>
    </div>
    """
  end

  defp input_border([] = _errors),
    do: "border-gray-300 focus:ring-indigo-500 focus:border-indigo-500"

  defp input_border([_ | _] = _errors),
    do: "border-red-300 focus:ring-red-500 focus:border-red-500"

  @doc """
  Generates a generic error message.
  """
  attr :message, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def error(assigns) do
    ~H"""
    <div class={["rounded-md bg-red-50 p-2 my-2", @class]} {@rest}>
      <div class="flex">
        <div class="flex-shrink-0">
          <!-- Heroicon name: solid/x-circle -->
          <svg
            class="h-5 w-5 text-red-400"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <p class="pl-3 text-sm text-red-700"><%%= @message %></p>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :class, :string, default: nil
  attr :comment, :string, default: nil
  attr :bordered, :boolean, default: false
  attr :rest, :global

  def container(assigns) do
    ~H"""
    <div
      class={
        [
          "bg-white mt-4 space-y-2 space-x-0 sm:space-x-2",
          if(@bordered, do: "overflow-hidden shadow rounded-lg"),
          @class
        ]
      }
      {@rest}
    >
      <%%= render_slot(@inner_block) %>
    </div>
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

  attr :row_id, :any, default: nil
  attr :rest, :global
  attr :bordered, :boolean, default: false
  attr :rows, :list, required: true
  attr :class, :string, default: nil

  slot :col, required: true
  slot :title
  slot :subtitle

  def table(assigns) do
    ~H"""
    <div class={["bg-white overflow-hidden", @class]}>
      <div class="align-middle inline-block min-w-full border-b border-gray-200">
        <%%= if @title != [] || @subtitle != [] do %>
          <div class="px-4 py-5 sm:px-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900"><%%= render_slot(@title) %></h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500"><%%= render_slot(@subtitle) %></p>
          </div>
        <%% end %>
        <table class="min-w-full">
          <thead>
            <tr class="border-t border-gray-200">
              <%%= for col <- @col do %>
                <th class="px-6 py-3 border-b border-gray-200 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <span class="lg:pl-2"><%%= col.label %></span>
                </th>
              <%% end %>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-100">
            <%%= for row <- @rows do %>
              <tr id={@row_id && @row_id.(row)} class="hover:bg-gray-50">
                <%%= for col <- @col do %>
                  <td class={
                    ["px-6 py-3 whitespace-nowrap text-sm font-medium text-gray-900", col[:class]]
                  }>
                    <div class="flex items-center space-x-3 lg:pl-2">
                      <%%= render_slot(col, row) %>
                    </div>
                  </td>
                <%% end %>
              </tr>
            <%% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  slot :title
  slot :desc
  slot :icon
  slot :item

  def list(assigns) do
    ~H"""
    <div class="relative">
      <dt>
        <div class="absolute flex items-center justify-center h-12 w-12 rounded-md bg-indigo-500 text-white">
          <%%= for icon <- @icon do %>
            <img class="h-6 w-6" src={icon.src} />
          <%% end %>
        </div>
        <p class="ml-16 text-lg leading-6 font-medium text-gray-900"><%%= render_slot(@title) %></p>
      </dt>
      <dd class="mt-2 ml-16 text-base text-gray-500">
        <%%= render_slot(@desc) %>
      </dd>
      <ul class="list-disc mt-2 ml-20 pl-1 text-base text-indigo-600">
        <%%= for item <- @item do %>
          <li>
            <%%= render_slot(item) %>
          </li>
        <%% end %>
      </ul>
    </div>
    """
  end

  slot :inner_block, required: true
  slot :title, required: true
  slot :subtitle

  attr :action, :any
  attr :em, :string, default: nil

  def hero(assigns) do
    ~H"""
    <div class="sm:text-center lg:text-center">
      <h1 class="text-4xl tracking-tight font-extrabold text-gray-900 sm:text-5xl md:text-6xl">
        <%%= for title <- @title do %>
          <span class="block xl:inline"><%%= render_slot(title) %></span>
          <%%= if title[:em] do %>
            <span class="block text-indigo-600 xl:inline"><%%= title[:em] %></span>
          <%% end %>
        <%% end %>
      </h1>
      <p class="mt-3 text-base text-gray-500 sm:mt-5 sm:text-lg lg:max-w-xl lg:mx-auto md:mt-5 md:text-xl">
        <%%= render_slot(@subtitle) %>
      </p>
      <div class="mt-5 sm:mt-8 lg:flex lg:justify-center">
        <%%= for action <- @action do %>
          <div class="mt-2 lg:mt-0 lg:mr-3">
            <.link
              href={action.href}
              class={
                if action[:primary] do
                  "w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 md:py-4 md:text-lg md:px-10"
                else
                  "w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200 md:py-4 md:text-lg md:px-10"
                end
              }
            >
              <%%= render_slot(action) %>
            </.link>
          </div>
        <%% end %>
      </div>
    </div>
    <div class="py-12 bg-white">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mt-10">
          <dl class="space-y-10 md:space-y-0 md:grid md:grid-cols-2 md:gap-x-8 md:gap-y-10">
            <%%= render_slot(@inner_block) %>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      display: "inline-block",
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
    |> JS.push_focus()
    |> JS.show(
      to: "##{id}",
      display: "inline-block",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      display: "inline-block",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.focus_first(to: "##{id}")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.dispatch("click", to: "##{id} [data-modal-return]")
    |> JS.pop_focus()
  end

  def show_menu(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.push_focus()
    |> JS.show(
      to: "##{id}",
      time: 150,
      transition:
        {"transition-all transform ease-out duration-150", "opacity-0 scale-95",
         "opacity-100 scale-100"}
    )
    |> JS.focus_first(to: "##{id}")
  end

  def hide_menu(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}",
      time: 100,
      transition:
        {"transition-all transform ease-in duration-100", "opacity-100 scale-100",
         "opacity-0 scale-95"}
    )
    |> JS.pop_focus()
  end <%= if @gettext do %>

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
