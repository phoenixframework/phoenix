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
  """
  @spec reload(module) :: :ok | {:error, binary()}
  def reload(endpoint) do
    if Code.ensure_loaded?(Mix.Project), do: reload!(endpoint), else: :ok
  end

  @doc """
  Same as `reload/1` but it will raise if Mix is not available.
  """
  @spec reload!(module) :: :ok | {:error, binary()}
  defdelegate reload!(endpoint), to: Phoenix.CodeReloader.Server

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
    logo: "data:image/png;base64,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",
    monospace_font: "menlo, consolas, monospace"
  }

  @doc """
  API used by Plug to start the code reloader.
  """
  def init(opts), do: Keyword.put_new(opts, :reloader, &Phoenix.CodeReloader.reload/1)

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
        |> send_resp(500, template(output))
        |> halt()
    end
  end

  defp template(output) do
    {error, headline} = get_error_details(output)

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
        .exception-info > .subtext,
        .exception-info > .title {
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

        .exception-info > .title {
            font-size: #{:math.pow(1.2, 4)}em;
            line-height: 1.4;
            font-weight: 300;
            color: #{@style.primary};
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
        }
        </style>
    </head>
    <body>
        <div class="heading-block">
            <aside class="exception-logo"></aside>
            <header class="exception-info">
                <h5 class="error">#{error}</h5>
                <h1 class="title">#{headline}</h1>
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
    |> String.trim
    |> Plug.HTML.html_escape
  end

  defp get_error_details(output) do
    case Regex.run(~r/(?:\n|^)\*\* \(([^ ]+)\) (.*)(?:\n|$)/, output) do
      [_, error, headline] -> {error, format_output(headline)}
      _ -> {"CompileError", "Compilation error"}
    end
  end
end
