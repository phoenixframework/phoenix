import assert from "assert"
import jsdom from "jsdom"

import {Socket} from "../static/js/phoenix"

let socket

describe("protocol", () => {
  before(() => {
    socket = new Socket("/socket")
  })

  it("returns wss when location.protocal is https", () => {
    jsdom.changeURL(window, "https://example.com/");

    assert.equal(socket.protocol(), "wss")
  })

  it("returns ws when location.protocal is http", () => {
    jsdom.changeURL(window, "http://example.com/");

    assert.equal(socket.protocol(), "ws")
  })
})

describe("endpointURL", () => {
  it("returns endpoint for given full url", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("wss://example.org/chat")

    assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given protocol-relative url", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("//example.org/chat")

    assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given path on https host", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("/socket")

    assert.equal(socket.endPointURL(), "wss://example.com/socket/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given path on http host", () => {
    jsdom.changeURL(window, "http://example.com/");
    socket = new Socket("/socket")

    assert.equal(socket.endPointURL(), "ws://example.com/socket/websocket?vsn=1.0.0")
  })
})

