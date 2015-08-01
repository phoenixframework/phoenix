// To join channels, first import the phoenix channels `Socket` object and
// create a socket at the path mounted in your endpoint:
//
import {Socket} from "<%= phoenix_static_path %>/web/static/js/phoenix"

let socket = new Socket("/socket")

// When you connect, you'll often need to authetenticate the client. You can
// do this by exposing a `window.userToken` variable, you can render as a JS
// object in your layout. For example, imagine you have an authentication
// plug `MyAuth`, which authenticates the session and assigns a
// `:current_user`. If the current user exists you can assign the user's
// token in the connection for use in the layout:
//
// web/router.ex:
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     def put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
//
// Next you can expose the token to the client with a simple script tag:
//
// web/templates/layout/app.html.eex:
//
//     <script>window.userToken = "<%%= assigns[:user_token] %>";</script>
//
// Finally, connect the socket, pasing your token param:

socket.connect({userToken: window.userToken})

// Now that you are conneted, you can join channels with a topic:
let chan = socket.chan("topic:subtopic", {})
chan.join()
  .receive("ok", resp => { console.log("Joined succesffuly!", resp) })
  .receive("error", resp => { console.log("Unabled to join", resp) })

export default socket