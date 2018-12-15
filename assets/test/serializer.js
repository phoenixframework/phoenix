
export const encode = (msg) => {
  const payload = [
    msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload
  ]
  return JSON.stringify(payload)
}

export const decode = (rawPayload) => {
  const [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload)

  return {join_ref, ref, topic, event, payload}
}
