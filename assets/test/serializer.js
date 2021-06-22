
export const encode = (msg) => {
  let payload = [
    msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload
  ]
  return JSON.stringify(payload)
}

export const decode = (rawPayload) => {
  let [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload)

  return {join_ref, ref, topic, event, payload}
}
