/* The default serializer for encoding and decoding messages */
import {
  CHANNEL_EVENTS
} from "./constants"

export default {
  HEADER_LENGTH: 1,
  META_LENGTH: 4,
  KINDS: {push: 0, reply: 1, broadcast: 2},

  encode(msg, callback){
    if(msg.payload.constructor === ArrayBuffer){
      return callback(this.binaryEncode(msg))
    } else {
      let payload = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload]
      return callback(JSON.stringify(payload))
    }
  },

  decode(rawPayload, callback){
    if(rawPayload.constructor === ArrayBuffer){
      return callback(this.binaryDecode(rawPayload))
    } else {
      let [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload)
      return callback({join_ref, ref, topic, event, payload})
    }
  },

  // private

  binaryEncode(message){
    let {join_ref, ref, event, topic, payload} = message
    let encoder = new TextEncoder()
    let joinRefBytes = encoder.encode(join_ref)
    let refBytes = encoder.encode(ref)
    let topicBytes = encoder.encode(topic)
    let eventBytes = encoder.encode(event)

    this.assertFieldSize(joinRefBytes.byteLength, "join_ref")
    this.assertFieldSize(refBytes.byteLength, "ref")
    this.assertFieldSize(topicBytes.byteLength, "topic")
    this.assertFieldSize(eventBytes.byteLength, "event")

    let metaLength = this.META_LENGTH + joinRefBytes.byteLength + refBytes.byteLength + topicBytes.byteLength + eventBytes.byteLength
    let header = new ArrayBuffer(this.HEADER_LENGTH + metaLength)
    let headerBytes = new Uint8Array(header)
    let view = new DataView(header)
    let offset = 0

    view.setUint8(offset++, this.KINDS.push) // kind
    view.setUint8(offset++, joinRefBytes.byteLength)
    view.setUint8(offset++, refBytes.byteLength)
    view.setUint8(offset++, topicBytes.byteLength)
    view.setUint8(offset++, eventBytes.byteLength)
    headerBytes.set(joinRefBytes, offset); offset += joinRefBytes.byteLength
    headerBytes.set(refBytes, offset); offset += refBytes.byteLength
    headerBytes.set(topicBytes, offset); offset += topicBytes.byteLength
    headerBytes.set(eventBytes, offset); offset += eventBytes.byteLength

    var combined = new Uint8Array(header.byteLength + payload.byteLength)
    combined.set(headerBytes, 0)
    combined.set(new Uint8Array(payload), header.byteLength)

    return combined.buffer
  },

  assertFieldSize(size, name){
    if(size > 255){
      throw new Error(`unable to convert ${name} to binary: must be less than or equal to 255 bytes, but is ${size} bytes`)
    }
  },

  binaryDecode(buffer){
    let view = new DataView(buffer)
    let kind = view.getUint8(0)
    let decoder = new TextDecoder()
    switch(kind){
      case this.KINDS.push: return this.decodePush(buffer, view, decoder)
      case this.KINDS.reply: return this.decodeReply(buffer, view, decoder)
      case this.KINDS.broadcast: return this.decodeBroadcast(buffer, view, decoder)
    }
  },

  decodePush(buffer, view, decoder){
    let joinRefSize = view.getUint8(1)
    let topicSize = view.getUint8(2)
    let eventSize = view.getUint8(3)
    let offset = this.HEADER_LENGTH + this.META_LENGTH - 1 // pushes have no ref
    let joinRef = decoder.decode(buffer.slice(offset, offset + joinRefSize))
    offset = offset + joinRefSize
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize))
    offset = offset + topicSize
    let event = decoder.decode(buffer.slice(offset, offset + eventSize))
    offset = offset + eventSize
    let data = buffer.slice(offset, buffer.byteLength)
    return {join_ref: joinRef, ref: null, topic: topic, event: event, payload: data}
  },

  decodeReply(buffer, view, decoder){
    let joinRefSize = view.getUint8(1)
    let refSize = view.getUint8(2)
    let topicSize = view.getUint8(3)
    let eventSize = view.getUint8(4)
    let offset = this.HEADER_LENGTH + this.META_LENGTH
    let joinRef = decoder.decode(buffer.slice(offset, offset + joinRefSize))
    offset = offset + joinRefSize
    let ref = decoder.decode(buffer.slice(offset, offset + refSize))
    offset = offset + refSize
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize))
    offset = offset + topicSize
    let event = decoder.decode(buffer.slice(offset, offset + eventSize))
    offset = offset + eventSize
    let data = buffer.slice(offset, buffer.byteLength)
    let payload = {status: event, response: data}
    return {join_ref: joinRef, ref: ref, topic: topic, event: CHANNEL_EVENTS.reply, payload: payload}
  },

  decodeBroadcast(buffer, view, decoder){
    let topicSize = view.getUint8(1)
    let eventSize = view.getUint8(2)
    let offset = this.HEADER_LENGTH + 2
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize))
    offset = offset + topicSize
    let event = decoder.decode(buffer.slice(offset, offset + eventSize))
    offset = offset + eventSize
    let data = buffer.slice(offset, buffer.byteLength)

    return {join_ref: null, ref: null, topic: topic, event: event, payload: data}
  }
}
