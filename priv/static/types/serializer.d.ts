declare namespace _default {
    let HEADER_LENGTH: number;
    let META_LENGTH: number;
    namespace KINDS {
        let push: number;
        let reply: number;
        let broadcast: number;
    }
    /**
    * @template T
    * @param {ArrayBuffer | string} msg
    * @param {(msg: Message<unknown>) => T} callback
    * @returns {T}
    */
    function encode<T>(msg: ArrayBuffer | string, callback: (msg: Message<unknown>) => T): T;
    /**
    * @template T
    * @param {Message<Record<string, any>>} rawPayload
    * @param {(msg: ArrayBuffer | string) => T} callback
    * @returns {T}
    */
    function decode<T>(rawPayload: Message<Record<string, any>>, callback: (msg: ArrayBuffer | string) => T): T;
    /** @private */
    function binaryEncode(message: any): any;
    /** @private */
    function binaryDecode(buffer: any): {
        join_ref: any;
        ref: null;
        topic: any;
        event: any;
        payload: any;
    } | {
        join_ref: any;
        ref: any;
        topic: any;
        event: "phx_reply";
        payload: {
            status: any;
            response: any;
        };
    } | undefined;
    /** @private */
    function decodePush(buffer: any, view: any, decoder: any): {
        join_ref: any;
        ref: null;
        topic: any;
        event: any;
        payload: any;
    };
    /** @private */
    function decodeReply(buffer: any, view: any, decoder: any): {
        join_ref: any;
        ref: any;
        topic: any;
        event: "phx_reply";
        payload: {
            status: any;
            response: any;
        };
    };
    /** @private */
    function decodeBroadcast(buffer: any, view: any, decoder: any): {
        join_ref: null;
        ref: null;
        topic: any;
        event: any;
        payload: any;
    };
}
export default _default;
import type { Message } from "./types";
//# sourceMappingURL=serializer.d.ts.map