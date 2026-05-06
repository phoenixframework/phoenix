/**
 * @jest-environment node
 */

import {TextEncoder, TextDecoder} from "util"
import {Serializer} from "../js/phoenix"

let exampleMsg = {join_ref: "0", ref: "1", topic: "t", event: "e", payload: {foo: 1}}

let binPayload = () => {
  let buffer = new ArrayBuffer(1)
  new DataView(buffer).setUint8(0, 1)
  return buffer
}

describe("JSON", () => {
  it("encodes general pushes", (done) => {
    Serializer.encode(exampleMsg, (result) => {
      expect(result).toBe("[\"0\",\"1\",\"t\",\"e\",{\"foo\":1}]")
      done()
    })
  })

  it("decodes", (done) => {
    Serializer.decode("[\"0\",\"1\",\"t\",\"e\",{\"foo\":1}]", (result) => {
      expect(result).toEqual(exampleMsg)
      done()
    })
  })
})

describe("binary", () => {
  it("encodes", (done) => {
    let buffer = binPayload()
    let bin = "\0\x01\x01\x01\x0101te\x01"
    let decoder = new TextDecoder()
    Serializer.encode({join_ref: "0", ref: "1", topic: "t", event: "e", payload: buffer}, (result) => {
      expect(decoder.decode(result)).toBe(bin)
      done()
    })
  })

  it("encodes variable length segments", (done) => {
    let buffer = binPayload()
    let bin = "\0\x02\x01\x03\x02101topev\x01"
    let decoder = new TextDecoder()
    Serializer.encode({join_ref: "10", ref: "1", topic: "top", event: "ev", payload: buffer}, (result) => {
      expect(decoder.decode(result)).toBe(bin)
      done()
    })
  })

  it("decodes push", (done) => {
    let bin = "\0\x03\x03\n123topsome-event\x01\x01"
    let buffer = new TextEncoder().encode(bin).buffer
    let decoder = new TextDecoder()
    Serializer.decode(buffer, (result) => {
      expect(result.join_ref).toBe("123")
      expect(result.ref).toBeNull()
      expect(result.topic).toBe("top")
      expect(result.event).toBe("some-event")
      expect(result.payload.constructor).toBe(ArrayBuffer)
      expect(decoder.decode(result.payload)).toBe("\x01\x01")
      done()
    })
  })

  it("decodes reply", (done) => {
    let bin = "\x01\x03\x02\x03\x0210012topok\x01\x01"
    let buffer = new TextEncoder().encode(bin).buffer
    let decoder = new TextDecoder()
    Serializer.decode(buffer, (result) => {
      expect(result.join_ref).toBe("100")
      expect(result.ref).toBe("12")
      expect(result.topic).toBe("top")
      expect(result.event).toBe("phx_reply")
      expect(result.payload.status).toBe("ok")
      expect(result.payload.response.constructor).toBe(ArrayBuffer)
      expect(decoder.decode(result.payload.response)).toBe("\x01\x01")
      done()
    })
  })

  it("encodes non-ASCII metadata as UTF-8", (done) => {
    let buffer = binPayload()
    let topic = "room:café"
    let event = "π"
    let joinRef = "🚀"
    let ref = "1"
    let encoder = new TextEncoder()
    let topicBytes = encoder.encode(topic)
    let eventBytes = encoder.encode(event)
    let joinRefBytes = encoder.encode(joinRef)
    let refBytes = encoder.encode(ref)

    Serializer.encode({join_ref: joinRef, ref: ref, topic: topic, event: event, payload: buffer}, (result) => {
      let bytes = new Uint8Array(result)
      expect(bytes[0]).toBe(0) // push kind
      expect(bytes[1]).toBe(joinRefBytes.byteLength) // 4 bytes for "🚀"
      expect(bytes[2]).toBe(refBytes.byteLength)
      expect(bytes[3]).toBe(topicBytes.byteLength) // 10 bytes for "room:café"
      expect(bytes[4]).toBe(eventBytes.byteLength) // 2 bytes for "π"

      let offset = 5
      expect(Array.from(bytes.slice(offset, offset + joinRefBytes.byteLength))).toEqual(Array.from(joinRefBytes))
      offset += joinRefBytes.byteLength
      expect(Array.from(bytes.slice(offset, offset + refBytes.byteLength))).toEqual(Array.from(refBytes))
      offset += refBytes.byteLength
      expect(Array.from(bytes.slice(offset, offset + topicBytes.byteLength))).toEqual(Array.from(topicBytes))
      offset += topicBytes.byteLength
      expect(Array.from(bytes.slice(offset, offset + eventBytes.byteLength))).toEqual(Array.from(eventBytes))
      offset += eventBytes.byteLength
      expect(bytes[offset]).toBe(1) // payload byte
      done()
    })
  })

  it("throws when a metadata field exceeds 255 UTF-8 bytes", () => {
    let buffer = binPayload()
    let big = "a".repeat(256)
    expect(() => {
      Serializer.encode({join_ref: "0", ref: "1", topic: big, event: "e", payload: buffer}, () => {})
    }).toThrow(/topic/)
  })

  it("decodes broadcast", (done) => {
    let bin = "\x02\x03\ntopsome-event\x01\x01"
    let buffer = new TextEncoder().encode(bin).buffer
    let decoder = new TextDecoder()
    Serializer.decode(buffer, (result) => {
      expect(result.join_ref).toBeNull()
      expect(result.ref).toBeNull()
      expect(result.topic).toBe("top")
      expect(result.event).toBe("some-event")
      expect(result.payload.constructor).toBe(ArrayBuffer)
      expect(decoder.decode(result.payload)).toBe("\x01\x01")
      done()
    })
  })
})
