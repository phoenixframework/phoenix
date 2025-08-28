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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.
<%= if @html do %>
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
<%= @live_comment %>import {Socket} from "<%= @phoenix_js_path %>"
<%= @live_comment %>import {LiveSocket} from "phoenix_live_view"
<%= @live_comment %>import {hooks as colocatedHooks} from "phoenix-colocated/<%= @web_app_name %>"
<%= @live_comment %>import topbar from "../vendor/topbar"

<%= @live_comment %>const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
<%= @live_comment %>const liveSocket = new LiveSocket("/live", Socket, {
<%= @live_comment %>  longPollFallbackMs: 2500,
<%= @live_comment %>  params: {_csrf_token: csrfToken},
<%= @live_comment %>  hooks: {...colocatedHooks},
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

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
<%= @live_comment %>if (process.env.NODE_ENV === "development") {
<%= @live_comment %>  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
<%= @live_comment %>    // Enable server log streaming to client.
<%= @live_comment %>    // Disable with reloader.disableServerLogs()
<%= @live_comment %>    reloader.enableServerLogs()
<%= @live_comment %>
<%= @live_comment %>    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
<%= @live_comment %>    //
<%= @live_comment %>    //   * click with "c" key pressed to open at caller location
<%= @live_comment %>    //   * click with "d" key pressed to open at function component definition location
<%= @live_comment %>    let keyDown
<%= @live_comment %>    window.addEventListener("keydown", e => keyDown = e.key)
<%= @live_comment %>    window.addEventListener("keyup", _e => keyDown = null)
<%= @live_comment %>    window.addEventListener("click", e => {
<%= @live_comment %>      if(keyDown === "c"){
<%= @live_comment %>        e.preventDefault()
<%= @live_comment %>        e.stopImmediatePropagation()
<%= @live_comment %>        reloader.openEditorAtCaller(e.target)
<%= @live_comment %>      } else if(keyDown === "d"){
<%= @live_comment %>        e.preventDefault()
<%= @live_comment %>        e.stopImmediatePropagation()
<%= @live_comment %>        reloader.openEditorAtDef(e.target)
<%= @live_comment %>      }
<%= @live_comment %>    }, true)
<%= @live_comment %>
<%= @live_comment %>    window.liveReloader = reloader
<%= @live_comment %>  })
<%= @live_comment %>}

<%= if not @live do %>
// Handle flash close
document.querySelectorAll("[role=alert][data-flash]").forEach((el) => {
  el.addEventListener("click", () => {
    el.setAttribute("hidden", "")
  })
})<% end %><% end %>