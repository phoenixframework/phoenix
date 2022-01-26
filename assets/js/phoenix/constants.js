export const globalSelf = typeof self !== "undefined" ? self : null
export const phxWindow = typeof window !== "undefined" ? window : null
export const global = globalSelf || phxWindow || global
export const DEFAULT_VSN = "2.0.0"
export const SOCKET_STATES = {connecting: 0, open: 1, closing: 2, closed: 3}
export const DEFAULT_TIMEOUT = 10000
export const WS_CLOSE_NORMAL = 1000
export const CHANNEL_STATES = {
  closed: "closed",
  errored: "errored",
  joined: "joined",
  joining: "joining",
  leaving: "leaving",
}
export const CHANNEL_EVENTS = {
  close: "phx_close",
  error: "phx_error",
  join: "phx_join",
  reply: "phx_reply",
  leave: "phx_leave"
}

export const TRANSPORTS = {
  longpoll: "longpoll",
  websocket: "websocket"
}
export const XHR_STATES = {
  complete: 4
}
