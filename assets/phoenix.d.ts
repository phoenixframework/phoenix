declare module 'phoenix' {
  type Ref = number;
  type Timeout = number;
  type ConnectionState = 'connecting' | 'open' | 'closing' | 'closed';

  class Push {
    constructor(
      channel: Channel,
      event: string,
      payload: Object,
      timeout: Timeout,
    );

    receive(status: string, callback: (response?: Object) => any): this;
  }

  class Channel {
    constructor(topic: string, params: Object | Function, socket: Socket);

    join(timeout?: Timeout): Push;
    push(event: string, payload: Object, timeout?: Timeout): Push;
    leave(timeout?: Timeout): Push;

    onClose(callback: Function);
    onError(callback: Function);

    on(event: string, callback: Function): Ref;
    off(event: string, ref: Ref);

    onMessage(event: string, payload: Object, ref: Ref): Object;
  }

  class SocketConnectOption {
    params: Object | Function;
    transport: any;
    timeout: Timeout;
    heartbeatIntervalMs: number;
    reconnectAfterMs: number;
    longpollerTimeout: number;
    encode: (payload: Object, callback: Function) => any;
    decode: (payload: string, callback: Function) => any;
    logger: (kind: string, message: string, data: Object) => void;
  }

  class Socket {
    constructor(endpoint: string, opts?: Partial<SocketConnectOption>);

    protocol(): string;
    endpointURL(): string;

    connect();
    disconnect(callback?: Function, code?: number, reason?: string);
    connectionState(): ConnectionState;
    isConnected(): boolean;

    remove(channel: Channel);
    channel(topic: string, chanParams?: Object): Channel;
    push(data: Object);

    log(kind: string, message: string, data: Object);
    hasLogger(): boolean;

    onOpen(callback: Function);
    onClose(callback: Function);
    onError(callback: Function);
    onMessage(callback: Function);

    makeRef(): string;
  }

  class Presence {
    constructor(channel: Channel, opts?: Object);

    onJoin(callback: Function);
    onLeave(callback: Function);
    onSync(callback: Function);
    list<T = any>(chooser?: Function): T[];
    inPendingSyncState(): boolean;

    static syncState(
      currentState: Object,
      newState: Object,
      onJoin: Function,
      onLeave: Function,
    ): Object;

    static syncDiff(
      currentState: Object,
      diff: {joins: Object; leaves: Object},
      onJoin: Function,
      onLeave: Function,
    ): Object;

    static list<T = any>(
      presenceData: Object,
      chooser?: (key: string, presence: Object) => T,
    ): T[];
  }
}
