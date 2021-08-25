// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "./vendor/some-package.js"
//
// Alternatively, you can `npm install some-package` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
<%= if @html do %>
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
<%= if !@live, do: "// " %>import {Socket} from "<%= @phoenix_js_path %>"
<%= if !@live, do: "// " %>import {LiveSocket} from "phoenix_live_view"
<%= if !@live, do: "// " %>import topbar from "../vendor/topbar"

<%= if !@live, do: "// " %>let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
<%= if !@live, do: "// " %>let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
<%= if !@live, do: "// " %>topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
<%= if !@live, do: "// " %>window.addEventListener("phx:page-loading-start", info => topbar.show())
<%= if !@live, do: "// " %>window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
<%= if !@live, do: "// " %>liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
<%= if !@live, do: "// " %>window.liveSocket = liveSocket
<% end %>