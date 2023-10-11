defmodule Phoenix.CodeReloader do
  @moduledoc """
  A plug and module to handle automatic code reloading.

  To avoid race conditions, all code reloads are funneled through a
  sequential call operation.
  """

  ## Server delegation

  @doc """
  Reloads code for the current Mix project by invoking the
  `:reloadable_compilers` on the list of `:reloadable_apps`.

  This is configured in your application environment like:

      config :your_app, YourAppWeb.Endpoint,
        reloadable_compilers: [:gettext, :elixir],
        reloadable_apps: [:ui, :backend]

  Keep in mind `:reloadable_compilers` must be a subset of the
  `:compilers` specified in `project/0` in your `mix.exs`.

  The `:reloadable_apps` defaults to `nil`. In such case
  default behaviour is to reload the current project if it
  consists of a single app, or all applications within an umbrella
  project. You can set `:reloadable_apps` to a subset of default
  applications to reload only some of them, an empty list - to
  effectively disable the code reloader, or include external
  applications from library dependencies.

  This function is a no-op and returns `:ok` if Mix is not available.

  ## Options

    * `:reloadable_args` - additional CLI args to pass to the compiler tasks.
      Defaults to `["--no-all-warnings"]` so only warnings related to the
      files being compiled are printed

  """
  @spec reload(module, keyword) :: :ok | {:error, binary()}
  def reload(endpoint, opts \\ []) do
    if Code.ensure_loaded?(Mix.Project), do: reload!(endpoint, opts), else: :ok
  end

  @doc """
  Same as `reload/1` but it will raise if Mix is not available.
  """
  @spec reload!(module, keyword) :: :ok | {:error, binary()}
  defdelegate reload!(endpoint, opts), to: Phoenix.CodeReloader.Server

  @doc """
  Synchronizes with the code server if it is alive.

  It returns `:ok`. If it is not running, it also returns `:ok`.
  """
  @spec sync :: :ok
  defdelegate sync, to: Phoenix.CodeReloader.Server

  ## Plug

  @behaviour Plug
  import Plug.Conn

  @style %{
    primary: "#EB532D",
    accent: "#a0b0c0",
    text_color: "#304050",
    logo:
      "data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgNzEgNDgiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgoJPHBhdGggZD0ibTI2LjM3MSAzMy40NzctLjU1Mi0uMWMtMy45Mi0uNzI5LTYuMzk3LTMuMS03LjU3LTYuODI5LS43MzMtMi4zMjQuNTk3LTQuMDM1IDMuMDM1LTQuMTQ4IDEuOTk1LS4wOTIgMy4zNjIgMS4wNTUgNC41NyAyLjM5IDEuNTU3IDEuNzIgMi45ODQgMy41NTggNC41MTQgNS4zMDUgMi4yMDIgMi41MTUgNC43OTcgNC4xMzQgOC4zNDcgMy42MzQgMy4xODMtLjQ0OCA1Ljk1OC0xLjcyNSA4LjM3MS0zLjgyOC4zNjMtLjMxNi43NjEtLjU5MiAxLjE0NC0uODg2bC0uMjQxLS4yODRjLTIuMDI3LjYzLTQuMDkzLjg0MS02LjIwNS43MzUtMy4xOTUtLjE2LTYuMjQtLjgyOC04Ljk2NC0yLjU4Mi0yLjQ4Ni0xLjYwMS00LjMxOS0zLjc0Ni01LjE5LTYuNjExLS43MDQtMi4zMTUuNzM2LTMuOTM0IDMuMTM1LTMuNi45NDguMTMzIDEuNzQ2LjU2IDIuNDYzIDEuMTY1LjU4My40OTMgMS4xNDMgMS4wMTUgMS43MzggMS40OTMgMi44IDIuMjUgNi43MTIgMi4zNzUgMTAuMjY1LS4wNjgtNS44NDItLjAyNi05LjgxNy0zLjI0LTEzLjMwOC03LjMxMy0xLjM2Ni0xLjU5NC0yLjctMy4yMTYtNC4wOTUtNC43ODUtMi42OTgtMy4wMzYtNS42OTItNS43MS05Ljc5LTYuNjIzQzEyLjgtLjYyMyA3Ljc0NS4xNCAyLjg5MyAyLjM2MSAxLjkyNiAyLjgwNC45OTcgMy4zMTkgMCA0LjE0OWMuNDk0IDAgLjc2My4wMDYgMS4wMzIgMCAyLjQ0Ni0uMDY0IDQuMjggMS4wMjMgNS42MDIgMy4wMjQuOTYyIDEuNDU3IDEuNDE1IDMuMTA0IDEuNzYxIDQuNzk4LjUxMyAyLjUxNS4yNDcgNS4wNzguNTQ0IDcuNjA1Ljc2MSA2LjQ5NCA0LjA4IDExLjAyNiAxMC4yNiAxMy4zNDYgMi4yNjcuODUyIDQuNTkxIDEuMTM1IDcuMTcyLjU1NVpNMTAuNzUxIDMuODUyYy0uOTc2LjI0Ni0xLjc1Ni0uMTQ4LTIuNTYtLjk2MiAxLjM3Ny0uMzQzIDIuNTkyLS40NzYgMy44OTctLjUyOC0uMTA3Ljg0OC0uNjA3IDEuMzA2LTEuMzM2IDEuNDlabTMyLjAwMiAzNy45MjRjLS4wODUtLjYyNi0uNjItLjkwMS0xLjA0LTEuMjI4LTEuODU3LTEuNDQ2LTQuMDMtMS45NTgtNi4zMzMtMi0xLjM3NS0uMDI2LTIuNzM1LS4xMjgtNC4wMzEtLjYxLS41OTUtLjIyLTEuMjYtLjUwNS0xLjI0NC0xLjI3Mi4wMTUtLjc4LjY5My0xIDEuMzEtMS4xODQuNTA1LS4xNSAxLjAyNi0uMjQ3IDEuNi0uMzgyLTEuNDYtLjkzNi0yLjg4Ni0xLjA2NS00Ljc4Ny0uMy0yLjk5MyAxLjIwMi01Ljk0MyAxLjA2LTguOTI2LS4wMTctMS42ODQtLjYwOC0zLjE3OS0xLjU2My00LjczNS0yLjQwOGwtLjA0My4wM2EyLjk2IDIuOTYgMCAwIDAgLjA0LS4wMjljLS4wMzgtLjExNy0uMTA3LS4xMi0uMTk3LS4wNTRsLjEyMi4xMDdjMS4yOSAyLjExNSAzLjAzNCAzLjgxNyA1LjAwNCA1LjI3MSAzLjc5MyAyLjggNy45MzYgNC40NzEgMTIuNzg0IDMuNzNBNjYuNzE0IDY2LjcxNCAwIDAgMSAzNyA0MC44NzdjMS45OC0uMTYgMy44NjYuMzk4IDUuNzUzLjg5OVptLTkuMTQtMzAuMzQ1Yy0uMTA1LS4wNzYtLjIwNi0uMjY2LS40Mi0uMDY5IDEuNzQ1IDIuMzYgMy45ODUgNC4wOTggNi42ODMgNS4xOTMgNC4zNTQgMS43NjcgOC43NzMgMi4wNyAxMy4yOTMuNTEgMy41MS0xLjIxIDYuMDMzLS4wMjggNy4zNDMgMy4zOC4xOS0zLjk1NS0yLjEzNy02LjgzNy01Ljg0My03LjQwMS0yLjA4NC0uMzE4LTQuMDEuMzczLTUuOTYyLjk0LTUuNDM0IDEuNTc1LTEwLjQ4NS43OTgtMTUuMDk0LTIuNTUzWm0yNy4wODUgMTUuNDI1Yy43MDguMDU5IDEuNDE2LjEyMyAyLjEyNC4xODUtMS42LTEuNDA1LTMuNTUtMS41MTctNS41MjMtMS40MDQtMy4wMDMuMTctNS4xNjcgMS45MDMtNy4xNCAzLjk3Mi0xLjczOSAxLjgyNC0zLjMxIDMuODctNS45MDMgNC42MDQuMDQzLjA3OC4wNTQuMTE3LjA2Ni4xMTcuMzUuMDA1LjY5OS4wMjEgMS4wNDcuMDA1IDMuNzY4LS4xNyA3LjMxNy0uOTY1IDEwLjE0LTMuNy44OS0uODYgMS42ODUtMS44MTcgMi41NDQtMi43MS43MTYtLjc0NiAxLjU4NC0xLjE1OSAyLjY0NS0xLjA3Wm0tOC43NTMtNC42N2MtMi44MTIuMjQ2LTUuMjU0IDEuNDA5LTcuNTQ4IDIuOTQzLTEuNzY2IDEuMTgtMy42NTQgMS43MzgtNS43NzYgMS4zNy0uMzc0LS4wNjYtLjc1LS4xMTQtMS4xMjQtLjE3bC0uMDEzLjE1NmMuMTM1LjA3LjI2NS4xNTEuNDA1LjIwNy4zNTQuMTQuNzAyLjMwOCAxLjA3LjM5NSA0LjA4My45NzEgNy45OTIuNDc0IDExLjUxNi0xLjgwMyAyLjIyMS0xLjQzNSA0LjUyMS0xLjcwNyA3LjAxMy0xLjMzNi4yNTIuMDM4LjUwMy4wODMuNzU2LjEwNy4yMzQuMDIyLjQ3OS4yNTUuNzk1LjAwMy0yLjE3OS0xLjU3NC00LjUyNi0yLjA5Ni03LjA5NC0xLjg3MlptLTEwLjA0OS05LjU0NGMxLjQ3NS4wNTEgMi45NDMtLjE0MiA0LjQ4Ni0xLjA1OS0uNDUyLjA0LS42NDMuMDQtLjgyNy4wNzYtMi4xMjYuNDI0LTQuMDMzLS4wNC01LjczMy0xLjM4My0uNjIzLS40OTMtMS4yNTctLjk3NC0xLjg4OS0xLjQ1Ny0yLjUwMy0xLjkxNC01LjM3NC0yLjU1NS04LjUxNC0yLjUuMDUuMTU0LjA1NC4yNi4xMDguMzE1IDMuNDE3IDMuNDU1IDcuMzcxIDUuODM2IDEyLjM2OSA2LjAwOFptMjQuNzI3IDE3LjczMWMtMi4xMTQtMi4wOTctNC45NTItMi4zNjctNy41NzgtLjUzNyAxLjczOC4wNzggMy4wNDMuNjMyIDQuMTAxIDEuNzI4LjM3NC4zODguNzYzLjc2OCAxLjE4MiAxLjEwNiAxLjYgMS4yOSA0LjMxMSAxLjM1MiA1Ljg5Ni4xNTUtMS44NjEtLjcyNi0xLjg2MS0uNzI2LTMuNjAxLTIuNDUyWm0tMjEuMDU4IDE2LjA2Yy0xLjg1OC0zLjQ2LTQuOTgxLTQuMjQtOC41OS00LjAwOGE5LjY2NyA5LjY2NyAwIDAgMSAyLjk3NyAxLjM5Yy44NC41ODYgMS41NDcgMS4zMTEgMi4yNDMgMi4wNTUgMS4zOCAxLjQ3MyAzLjUzNCAyLjM3NiA0Ljk2MiAyLjA3LS42NTYtLjQxMi0xLjIzOC0uODQ4LTEuNTkyLTEuNTA3Wm0xNy4yOS0xOS4zMmMwLS4wMjMuMDAxLS4wNDUuMDAzLS4wNjhsLS4wMDYuMDA2LjAwNi0uMDA2LS4wMzYtLjAwNC4wMjEuMDE4LjAxMi4wNTNabS0yMCAxNC43NDRhNy42MSA3LjYxIDAgMCAwLS4wNzItLjA0MS4xMjcuMTI3IDAgMCAwIC4wMTUuMDQzYy4wMDUuMDA4LjAzOCAwIC4wNTgtLjAwMlptLS4wNzItLjA0MS0uMDA4LS4wMzQtLjAwOC4wMS4wMDgtLjAxLS4wMjItLjAwNi4wMDUuMDI2LjAyNC4wMTRaIgogICAgICAgICAgICBmaWxsPSIjRkQ0RjAwIiAvPgo8L3N2Zz4K",
    monospace_font: "menlo, consolas, monospace"
  }

  @doc """
  API used by Plug to start the code reloader.
  """
  def init(opts) do
    Keyword.put_new(opts, :reloader, &Phoenix.CodeReloader.reload/2)
  end

  @doc """
  API used by Plug to invoke the code reloader on every request.
  """
  def call(conn, opts) do
    case opts[:reloader].(conn.private.phoenix_endpoint, opts) do
      :ok ->
        conn

      {:error, output} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(500, template(output))
        |> halt()
    end
  end

  defp template(output) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>CompileError</title>
        <meta name="viewport" content="width=device-width">
        <style>/*! normalize.css v4.2.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,details,figcaption,figure,footer,header,main,menu,nav,section,summary{display:block}audio,canvas,progress,video{display:inline-block}audio:not([controls]){display:none;height:0}progress{vertical-align:baseline}template,[hidden]{display:none}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}dfn{font-style:italic}h1{font-size:2em;margin:0.67em 0}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-0.25em}sup{top:-0.5em}img{border-style:none}svg:not(:root){overflow:hidden}code,kbd,pre,samp{font-family:monospace, monospace;font-size:1em}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}button,input,optgroup,select,textarea{font:inherit;margin:0}optgroup{font-weight:bold}button,input{overflow:visible}button,select{text-transform:none}button,html [type="button"],[type="reset"],[type="submit"]{-webkit-appearance:button}button::-moz-focus-inner,[type="button"]::-moz-focus-inner,[type="reset"]::-moz-focus-inner,[type="submit"]::-moz-focus-inner{border-style:none;padding:0}button:-moz-focusring,[type="button"]:-moz-focusring,[type="reset"]:-moz-focusring,[type="submit"]:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid #c0c0c0;margin:0 2px;padding:0.35em 0.625em 0.75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}textarea{overflow:auto}[type="checkbox"],[type="radio"]{box-sizing:border-box;padding:0}[type="number"]::-webkit-inner-spin-button,[type="number"]::-webkit-outer-spin-button{height:auto}[type="search"]{-webkit-appearance:textfield;outline-offset:-2px}[type="search"]::-webkit-search-cancel-button,[type="search"]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-input-placeholder{color:inherit;opacity:0.54}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}</style>
        <style>
        html, body, td, input {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto", "Oxygen", "Ubuntu", "Cantarell", "Fira Sans", "Droid Sans", "Helvetica Neue", sans-serif;
        }

        * {
            box-sizing: border-box;
        }

        html {
            font-size: 15px;
            line-height: 1.6;
            background: #fff;
            color: #{@style.text_color};
        }

        @media (max-width: 768px) {
            html {
                 font-size: 14px;
            }
        }

        @media (max-width: 480px) {
            html {
                 font-size: 13px;
            }
        }

        button:focus,
        summary:focus {
            outline: 0;
        }

        summary {
            cursor: pointer;
        }

        pre {
            font-family: #{@style.monospace_font};
            max-width: 100%;
        }

        .heading-block {
            background: #f9f9fa;
        }

        .heading-block,
        .output-block {
            padding: 48px;
        }

        @media (max-width: 768px) {
            .heading-block,
            .output-block {
                padding: 32px;
            }
        }

        @media (max-width: 480px) {
            .heading-block,
            .output-block {
                padding: 16px;
            }
        }

        /*
         * Exception logo
         */

        .exception-logo {
            position: absolute;
            right: 48px;
            top: 48px;
            pointer-events: none;
            width: 100%;
        }

        .exception-logo:before {
            content: '';
            display: block;
            height: 64px;
            width: 100%;
            background-size: auto 100%;
            background-image: url("#{@style.logo}");
            background-position: right 0;
            background-repeat: no-repeat;
            margin-bottom: 16px;
        }

        @media (max-width: 768px) {
            .exception-logo {
                position: static;
            }

            .exception-logo:before {
                height: 32px;
                background-position: left 0;
            }
        }

        @media (max-width: 480px) {
            .exception-logo {
                display: none;
            }
        }

        /*
         * Exception info
         */

        /* Compensate for logo placement */
        @media (min-width: 769px) {
            .exception-info {
                max-width: 90%;
            }
        }

        .exception-info > .error,
        .exception-info > .subtext {
            margin: 0;
            padding: 0;
        }

        .exception-info > .error {
            font-size: 1em;
            font-weight: 700;
            color: #{@style.primary};
        }

        .exception-info > .subtext {
            font-size: 1em;
            font-weight: 400;
            color: #{@style.accent};
        }

        @media (max-width: 768px) {
            .exception-info > .title {
                font-size: #{:math.pow(1.15, 4)}em;
            }
        }

        @media (max-width: 480px) {
            .exception-info > .title {
                font-size: #{:math.pow(1.1, 4)}em;
            }
        }

        .code-block {
            margin: 0;
            font-size: .85em;
            line-height: 1.6;
            white-space: pre-wrap;
        }
        </style>
    </head>
    <body>
        <div class="heading-block">
            <aside class="exception-logo"></aside>
            <header class="exception-info">
                <h5 class="error">Compilation error</h5>
                <h5 class="subtext">Console output is shown below.</h5>
            </header>
        </div>
        <div class="output-block">
            <pre class="code code-block">#{format_output(output)}</pre>
        </div>
    </body>
    </html>
    """
  end

  defp format_output(output) do
    output
    |> String.trim()
    |> Plug.HTML.html_escape()
  end
end
