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
    let metaLength = this.META_LENGTH + join_ref.length + ref.length + topic.length + event.length
    let header = new ArrayBuffer(this.HEADER_LENGTH + metaLength)
    let view = new DataView(header)
    let offset = 0

    view.setUint8(offset++, this.KINDS.push) // kind
    view.setUint8(offset++, join_ref.length)
    view.setUint8(offset++, ref.length)
    view.setUint8(offset++, topic.length)
    view.setUint8(offset++, event.length)
    Array.from(join_ref, char => view.setUint8(offset++, char.charCodeAt(0)))
    Array.from(ref, char => view.setUint8(offset++, char.charCodeAt(0)))
    Array.from(topic, char => view.setUint8(offset++, char.charCodeAt(0)))
    Array.from(event, char => view.setUint8(offset++, char.charCodeAt(0)))

    var combined = new Uint8Array(header.byteLength + payload.byteLength)
    combined.set(new Uint8Array(header), 0)
    combined.set(new Uint8Array(payload), header.byteLength)

    return combined.buffer
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
