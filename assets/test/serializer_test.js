import assert from "assert"

import {Serializer} from "../js/phoenix"

let exampleMsg = {join_ref: "0", ref: "1", topic: "t", event: "e", payload: {foo: 1}}

let binPayload = () => {
  let buffer = new ArrayBuffer(1)
  new DataView(buffer).setUint8(0, 1)
  return buffer
}

describe("JSON", function(){
  it("encodes general pushes", function(done){
    Serializer.encode(exampleMsg, result => {
      assert.equal(result, "[\"0\",\"1\",\"t\",\"e\",{\"foo\":1}]")
      done()
    })
  })

  it("decodes", function(done){
    Serializer.decode("[\"0\",\"1\",\"t\",\"e\",{\"foo\":1}]", result => {
      assert.deepEqual(result, exampleMsg)
      done()
    })
  })
})

describe("binary", function(){
  it("encodes", function(done){
    let buffer = binPayload()
    let bin = "\0\x01\x01\x01\x0101te\x01"
    let decoder = new TextDecoder()
    Serializer.encode({join_ref: "0", ref: "1", topic: "t", event: "e", payload: buffer}, result => {
      assert.equal(decoder.decode(result), bin)
      done()
    })
  })

  it("encodes variable length segments", function(done){
    let buffer = binPayload()
    let bin = "\0\x02\x01\x03\x02101topev\x01"
    let decoder = new TextDecoder()
    Serializer.encode({join_ref: "10", ref: "1", topic: "top", event: "ev", payload: buffer}, result => {
      assert.equal(decoder.decode(result), bin)
      done()
    })
  })

  it("decodes push", function(done){
    let bin = "\0\x03\x03\n123topsome-event\x01\x01"
    let buffer = (new TextEncoder()).encode(bin).buffer
    let decoder = new TextDecoder()
    Serializer.decode(buffer, result => {
      assert.equal(result.join_ref, "123")
      assert.equal(result.ref, null)
      assert.equal(result.topic, "top")
      assert.equal(result.event, "some-event")
      assert.equal(result.payload.constructor, ArrayBuffer)
      assert.equal(decoder.decode(result.payload), "\x01\x01")
      done()
    })
  })

  it("decodes reply", function(done){
    let bin = "\x01\x03\x02\x03\x0210012topok\x01\x01"
    let buffer = (new TextEncoder()).encode(bin).buffer
    let decoder = new TextDecoder()
    Serializer.decode(buffer, result => {
      assert.equal(result.join_ref, "100")
      assert.equal(result.ref, "12")
      assert.equal(result.topic, "top")
      assert.equal(result.event, "phx_reply")
      assert.equal(result.payload.status, "ok")
      assert.equal(result.payload.response.constructor, ArrayBuffer)
      assert.equal(decoder.decode(result.payload.response), "\x01\x01")
      done()
    })
  })

  it("decodes broadcast", function(done){
    let bin = "\x02\x03\ntopsome-event\x01\x01"
    let buffer = (new TextEncoder()).encode(bin).buffer
    let decoder = new TextDecoder()
    Serializer.decode(buffer, result => {
      assert.equal(result.join_ref, null)
      assert.equal(result.ref, null)
      assert.equal(result.topic, "top")
      assert.equal(result.event, "some-event")
      assert.equal(result.payload.constructor, ArrayBuffer)
      assert.equal(decoder.decode(result.payload), "\x01\x01")
      done()
    })
  })
})

