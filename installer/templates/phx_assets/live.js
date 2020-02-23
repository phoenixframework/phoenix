// NOTE: The contents of this file will only be executed if
// you need the following statement in "assets/js/app.js"
// import liveSocket from "./live"

import {LiveSocket} from "phoenix_live_view"
let liveSocket = new LiveSocket("/live")
liveSocket.connect()

export default liveSocket
