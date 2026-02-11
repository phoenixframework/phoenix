export default class LongPoll {
    constructor(endPoint: any, protocols: any);
    authToken: string | undefined;
    endPoint: any;
    token: any;
    skipHeartbeat: boolean;
    reqs: Set<any>;
    awaitingBatchAck: boolean;
    currentBatch: any[] | null;
    currentBatchTimer: number | null;
    batchBuffer: any[];
    onopen: () => void;
    onerror: () => void;
    onmessage: () => void;
    onclose: () => void;
    pollEndpoint: any;
    readyState: 0;
    normalizeEndpoint(endPoint: any): any;
    endpointURL(): any;
    closeAndRetry(code: any, reason: any, wasClean: any): void;
    ontimeout(): void;
    isActive(): boolean;
    poll(): void;
    send(body: any): void;
    batchSend(messages: any): void;
    close(code: any, reason: any, wasClean: any): void;
    ajax(method: any, headers: any, body: any, onCallerTimeout: any, callback: any): void;
}
//# sourceMappingURL=longpoll.d.ts.map