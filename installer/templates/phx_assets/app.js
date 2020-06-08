// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
<%= if html do %>import "phoenix_html"<% end %><%= if live do %>
import {Socket} from "phoenix"
import NProgress from "nprogress"
import {LiveSocket} from "phoenix_live_view"

let Hooks = {}
function handle_modal_keydown(e) {
  if (e.key === 'Tab') {
    // trap focus
    const nodes = this.el.querySelectorAll('*')
    const tabbable = Array.from(nodes).filter(n => n.tabIndex >= 0)

    let index = tabbable.indexOf(document.activeElement)
    if (index === -1 && e.shiftKey) index = 0

    index += tabbable.length + (e.shiftKey ? -1 : 1)
    index %= tabbable.length

    tabbable[index].focus()
    e.preventDefault()
  }
}
Hooks.TrapFokus = {
  mounted() {
    this.previously_focused = typeof document !== 'undefined' && document.activeElement
    this.handler = handle_modal_keydown.bind(this)
    window.addEventListener("keydown", this.handler)
  },
  beforeDestroy() {
    this.previously_focused.focus()
    window.removeEventListener("keydown", this.handler)
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
<% end %>
