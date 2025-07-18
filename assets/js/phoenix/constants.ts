export const globalSelf = typeof self !== "undefined" ? self : null;
export const phxWindow = typeof window !== "undefined" ? window : null;
export const global = globalSelf || phxWindow || globalThis;
export const DEFAULT_VSN = "2.0.0";

export const SOCKET_STATES = {
  connecting: 0,
  open: 1,
  closing: 2,
  closed: 3,
} as const;

export type SocketState = (typeof SOCKET_STATES)[keyof typeof SOCKET_STATES];

export const DEFAULT_TIMEOUT = 10000;
export const WS_CLOSE_NORMAL = 1000;

export const CHANNEL_STATES = {
  closed: "closed",
  errored: "errored",
  joined: "joined",
  joining: "joining",
  leaving: "leaving",
} as const;

export type ChannelState = (typeof CHANNEL_STATES)[keyof typeof CHANNEL_STATES];

export const CHANNEL_EVENTS = {
  close: "phx_close",
  error: "phx_error",
  join: "phx_join",
  reply: "phx_reply",
  leave: "phx_leave",
} as const;

export type ChannelEvent = (typeof CHANNEL_EVENTS)[keyof typeof CHANNEL_EVENTS];

export const TRANSPORTS = {
  longpoll: "longpoll",
  websocket: "websocket",
} as const;

export type Transport = (typeof TRANSPORTS)[keyof typeof TRANSPORTS];

export const XHR_STATES = {
  complete: 4,
} as const;

export const AUTH_TOKEN_PREFIX = "base64url.bearer.phx.";
