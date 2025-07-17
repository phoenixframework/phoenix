import { Message } from "../js/phoenix/serializer";

export const encode = (msg: Message): string => {
  const payload = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload];
  return JSON.stringify(payload);
};

export const decode = (rawPayload: string): Message => {
  const [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload);

  return { join_ref, ref, topic, event, payload };
};
