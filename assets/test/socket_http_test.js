/**
 * @jest-environment jsdom
 * @jest-environment-options {"url": "http://example.com/"}
 */
import {Socket} from "../js/phoenix"

// sadly, jsdom can only be configured globally for a file

describe("protocol", function (){
  it("returns ws when location.protocol is http", function (){
    const socket = new Socket("/socket")
    expect(socket.protocol()).toBe("ws")
  })
})

describe("endpointURL", function (){
  it("returns endpoint for given path on http host", function (){
    const socket = new Socket("/socket")
    expect(socket.endPointURL()).toBe(
      "ws://example.com/socket/websocket?vsn=2.0.0",
    )
  })
})
