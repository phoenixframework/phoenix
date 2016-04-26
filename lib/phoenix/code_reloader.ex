defmodule Phoenix.CodeReloader do
  @moduledoc """
  A plug and module to handle automatic code reloading.

  For each request, Phoenix checks if any of the modules previously
  compiled requires recompilation via `__phoenix_recompile__?/0` and then
  calls `mix compile` for sources exclusive to the `web` directory.

  To avoid race conditions, all code reloads are funneled through a
  sequential call operation.
  """

  ## Server delegation

  @doc """
  Reloads code for the current Mix project by invoking the
  `:reloadable_compilers`.

  This is configured in your application environment like:

      config :your_app, YourApp.Endpoint,
        reloadable_compilers: [:gettext, :phoenix, :elixir]

  Keep in mind `:reloadable_compilers` must be a subset of the
  `:compilers` specified in `project/0` in your `mix.exs`.
  """
  @spec reload!(module) :: :ok | {:error, binary()}
  defdelegate reload!(endpoint), to: Phoenix.CodeReloader.Server

  ## Plug

  @behaviour Plug
  import Plug.Conn

  @doc """
  API used by Plug to start the code reloader.
  """
  def init(opts), do: Keyword.put_new(opts, :reloader, &Phoenix.CodeReloader.reload!/1)

  @doc """
  API used by Plug to invoke the code reloader on every request.
  """
  def call(conn, opts) do
    case opts[:reloader].(conn.private.phoenix_endpoint) do
      :ok ->
        conn
      {:error, output} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(500, template(conn, output))
        |> halt()
    end
  end

  defp template(conn, output) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>CompilationError at #{method(conn)} #{conn.request_path}</title>
        <style>
        * {
            margin: 0;
            padding: 0;
        }

        body {
            font-size: 10pt;
            font-family: helvetica neue, lucida grande, sans-serif;
            line-height: 1.5;
            color: #333;
            text-shadow: 0 1px 0 rgba(255, 255, 255, 0.6);
        }

        html {
            background: #f0f0f5;
        }

        header.exception {
            padding: 18px 20px;

            height: 59px;
            min-height: 59px;

            overflow: hidden;

            background-color: #20202a;
            color: #aaa;
            text-shadow: 0 1px 0 rgba(0, 0, 0, 0.3);
            font-weight: 200;
            box-shadow: inset 0 -5px 3px -3px rgba(0, 0, 0, 0.05), inset 0 -1px 0 rgba(0, 0, 0, 0.05);

            -webkit-text-smoothing: antialiased;
        }

        header.exception h2 {
            font-weight: 200;
            font-size: 11pt;
            padding-bottom: 2pt;
        }

        header.exception h2,
        header.exception p {
            line-height: 1.4em;
            height: 1.4em;
            overflow: hidden;
            white-space: pre;
            text-overflow: ellipsis;
        }

        header.exception h2 strong {
            font-weight: 700;
            color: #7E5ABE;
        }

        header.exception p {
            font-weight: 200;
            font-size: 18pt;
            color: white;
        }

        pre, code {
            font-family: menlo, lucida console, monospace;
            font-size: 9pt;
        }

        .trace_info {
            margin: 10px;
            background: #fff;
            padding: 6px;
            border-radius: 3px;
            margin-bottom: 2px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.03), 1px 1px 0 rgba(0, 0, 0, 0.05), -1px 1px 0 rgba(0, 0, 0, 0.05), 0 0 0 4px rgba(0, 0, 0, 0.04);
        }

        .code {
            background: #fff;
            box-shadow: inset 3px 3px 3px rgba(0, 0, 0, 0.1), inset 0 0 0 1px rgba(0, 0, 0, 0.1);
            margin-bottom: -1px;
            padding: 10px;
            overflow: auto;
        }

        .code::-webkit-scrollbar {
            width: 10px;
            height: 10px;
        }

        .code::-webkit-scrollbar-thumb {
            background: #ccc;
            border-radius: 5px;
        }

        .code:hover::-webkit-scrollbar-thumb {
            background: #888;
        }
        </style>
    </head>
    <body>
        <div class="top">
            <header class="exception">
                <h2><strong>CompilationError</strong> <span>at #{method(conn)} #{conn.request_path}</span></h2>
                <p>Showing console output</p>
            </header>
        </div>

        <header class="trace_info">
            <div class="code">
              <pre>#{String.strip(output)}</pre>
            </div>
        </header>
    </body>
    </html>
    """
  end

  defp method(%Plug.Conn{method: method}), do: method
end
