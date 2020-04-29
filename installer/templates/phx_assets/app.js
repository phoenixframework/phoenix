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

// The _csrf_token is necessary to load the current session into the LiveView.
// The _cache_static_manifest_hash is used to detect whenever there is a new
// deploy and trigger a reload of the assets. The "PHOENIX_CACHE_STATIC_MANIFEST_HASH"
// will be automatically replaced by a hash by running `mix phx.digest` in prod.
let params = {
  _csrf_token: document.querySelector("meta[name='csrf-token']").getAttribute("content"),
  _cache_static_manifest_hash: "PHOENIX_CACHE_STATIC_MANIFEST_HASH"
}

let liveSocket = new LiveSocket("/live", Socket, {params: params})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket
<% end %>