// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

// And connect to the path in "<%= web_prefix %>/endpoint.ex". We pass the
// token for authentication.
//
// Read the [`Using Token Authentication`](https://hexdocs.pm/phoenix/channels.html#using-token-authentication)
// section to see how the token should be used.
let socket = new Socket("/socket", {authToken: window.userToken})
socket.connect()

// Now that you are connected, you can join channels with a topic.
// Let's assume you have a channel with a topic named `room` and the
// subtopic is its id - in this case 42:
let channel = socket.channel("room:42", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
