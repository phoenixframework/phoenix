export const globalSelf: (Window & typeof globalThis) | null;
export const phxWindow: (Window & typeof globalThis) | null;
export const global: typeof globalThis;
export const DEFAULT_VSN: "2.0.0";
export const DEFAULT_TIMEOUT: 10000;
export const WS_CLOSE_NORMAL: 1000;
export namespace SOCKET_STATES {
    let connecting: 0;
    let open: 1;
    let closing: 2;
    let closed: 3;
}
export namespace CHANNEL_STATES {
    let closed_1: "closed";
    export { closed_1 as closed };
    export let errored: "errored";
    export let joined: "joined";
    export let joining: "joining";
    export let leaving: "leaving";
}
export namespace CHANNEL_EVENTS {
    let close: "phx_close";
    let error: "phx_error";
    let join: "phx_join";
    let reply: "phx_reply";
    let leave: "phx_leave";
}
export namespace TRANSPORTS {
    let longpoll: "longpoll";
    let websocket: "websocket";
}
export namespace XHR_STATES {
    let complete: 4;
}
export const AUTH_TOKEN_PREFIX: "base64url.bearer.phx.";
//# sourceMappingURL=constants.d.ts.map