// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
<%= if @html do %>
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
<%= @live_comment %>import {Socket} from "<%= @phoenix_js_path %>"
<%= @live_comment %>import {LiveSocket} from "phoenix_live_view"
<%= @live_comment %>import topbar from "../vendor/topbar"

<%= @live_comment %>let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
<%= @live_comment %>let liveSocket = new LiveSocket("/live", Socket, {
<%= @live_comment %>  longPollFallbackMs: 2500,
<%= @live_comment %>  params: {_csrf_token: csrfToken}
<%= @live_comment %>})

// Show progress bar on live navigation and form submits
<%= @live_comment %>topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
<%= @live_comment %>window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
<%= @live_comment %>window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
<%= @live_comment %>liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
<%= @live_comment %>window.liveSocket = liveSocket
<% end %>
