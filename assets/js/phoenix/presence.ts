import type Channel from "./channel";

export interface PresenceMeta {
  phx_ref: string;
  [key: string]: any;
}

export interface PresenceState {
  metas: PresenceMeta[];
  [key: string]: any;
}

export interface PresenceMap {
  [key: string]: PresenceState;
}

export interface PresenceDiff {
  joins: PresenceMap;
  leaves: PresenceMap;
}

export interface PresenceOptions {
  events?: {
    state: string;
    diff: string;
  };
}

export type PresenceCallback = (
  key: string,
  current: PresenceState | undefined,
  newPres: PresenceState,
) => void;
export type PresenceSyncCallback = () => void;
export type PresenceChooser<T = PresenceState> = (
  key: string,
  presence: PresenceState,
) => T;

/**
 * Initializes the Presence
 * @param channel - The Channel
 * @param opts - The options, for example `{events: {state: "state", diff: "diff"}}`
 */
export default class Presence {
  private state: PresenceMap;
  private pendingDiffs: PresenceDiff[];
  private channel: Channel;
  private joinRef: string | null;
  private caller: {
    onJoin: PresenceCallback;
    onLeave: PresenceCallback;
    onSync: PresenceSyncCallback;
  };

  constructor(channel: Channel, opts: PresenceOptions = {}) {
    const events = opts.events || {
      state: "presence_state",
      diff: "presence_diff",
    };
    this.state = {};
    this.pendingDiffs = [];
    this.channel = channel;
    this.joinRef = null;
    this.caller = {
      onJoin: function () {},
      onLeave: function () {},
      onSync: function () {},
    };

    this.channel.on(events.state, (newState: PresenceMap) => {
      const { onJoin, onLeave, onSync } = this.caller;

      this.joinRef = this.channel.joinRef();
      this.state = Presence.syncState(this.state, newState, onJoin, onLeave);

      this.pendingDiffs.forEach((diff) => {
        this.state = Presence.syncDiff(this.state, diff, onJoin, onLeave);
      });
      this.pendingDiffs = [];
      onSync();
    });

    this.channel.on(events.diff, (diff: PresenceDiff) => {
      const { onJoin, onLeave, onSync } = this.caller;

      if (this.inPendingSyncState()) {
        this.pendingDiffs.push(diff);
      } else {
        this.state = Presence.syncDiff(this.state, diff, onJoin, onLeave);
        onSync();
      }
    });
  }

  /**
   * @internal
   * @private
   */
  onJoin(callback: PresenceCallback): void {
    this.caller.onJoin = callback;
  }

  /**
   * @internal
   * @private
   */
  onLeave(callback: PresenceCallback): void {
    this.caller.onLeave = callback;
  }

  /**
   * @internal
   * @private
   */
  onSync(callback: PresenceSyncCallback): void {
    this.caller.onSync = callback;
  }

  /**
   * @internal
   * @private
   */
  list<T = PresenceState>(by?: PresenceChooser<T>): T[] {
    return Presence.list(this.state, by);
  }

  /**
   * @internal
   * @private
   */
  inPendingSyncState(): boolean {
    return !this.joinRef || this.joinRef !== this.channel.joinRef();
  }

  // lower-level public static API

  /**
   * Used to sync the list of presences on the server
   * with the client's state. An optional `onJoin` and `onLeave` callback can
   * be provided to react to changes in the client's local presences across
   * disconnects and reconnects with the server.
   */
  static syncState(
    currentState: PresenceMap,
    newState: PresenceMap,
    onJoin?: PresenceCallback,
    onLeave?: PresenceCallback,
  ): PresenceMap {
    const state = this.clone(currentState);
    const joins: PresenceMap = {};
    const leaves: PresenceMap = {};

    this.map(state, (key, presence) => {
      if (!newState[key]) {
        leaves[key] = presence;
      }
    });
    this.map(newState, (key, newPresence) => {
      const currentPresence = state[key];
      if (currentPresence) {
        const newRefs = newPresence.metas.map((m) => m.phx_ref);
        const curRefs = currentPresence.metas.map((m) => m.phx_ref);
        const joinedMetas = newPresence.metas.filter(
          (m) => curRefs.indexOf(m.phx_ref) < 0,
        );
        const leftMetas = currentPresence.metas.filter(
          (m) => newRefs.indexOf(m.phx_ref) < 0,
        );
        if (joinedMetas.length > 0) {
          joins[key] = newPresence;
          joins[key]!.metas = joinedMetas;
        }
        if (leftMetas.length > 0) {
          leaves[key] = this.clone(currentPresence);
          leaves[key]!.metas = leftMetas;
        }
      } else {
        joins[key] = newPresence;
      }
    });
    return this.syncDiff(
      state,
      { joins: joins, leaves: leaves },
      onJoin,
      onLeave,
    );
  }

  /**
   * Used to sync a diff of presence join and leave
   * events from the server, as they happen. Like `syncState`, `syncDiff`
   * accepts optional `onJoin` and `onLeave` callbacks to react to a user
   * joining or leaving from a device.
   */
  static syncDiff(
    state: PresenceMap,
    diff: PresenceDiff,
    onJoin?: PresenceCallback,
    onLeave?: PresenceCallback,
  ): PresenceMap {
    const { joins, leaves } = this.clone(diff);
    if (!onJoin) {
      onJoin = function () {};
    }
    if (!onLeave) {
      onLeave = function () {};
    }

    this.map(joins, (key, newPresence) => {
      const currentPresence = state[key];
      state[key] = this.clone(newPresence);
      if (currentPresence) {
        const joinedRefs = state[key]!.metas.map((m) => m.phx_ref);
        const curMetas = currentPresence.metas.filter(
          (m) => joinedRefs.indexOf(m.phx_ref) < 0,
        );
        state[key]!.metas.unshift(...curMetas);
      }
      onJoin!(key, currentPresence, newPresence);
    });
    this.map(leaves, (key, leftPresence) => {
      const currentPresence = state[key];
      if (!currentPresence) {
        return;
      }
      const refsToRemove = leftPresence.metas.map((m) => m.phx_ref);
      currentPresence.metas = currentPresence.metas.filter((p) => {
        return refsToRemove.indexOf(p.phx_ref) < 0;
      });
      onLeave!(key, currentPresence, leftPresence);
      if (currentPresence.metas.length === 0) {
        delete state[key];
      }
    });
    return state;
  }

  /**
   * Returns the array of presences, with selected metadata.
   */
  static list<T = PresenceState>(
    presences: PresenceMap,
    chooser?: PresenceChooser<T>,
  ): T[] {
    if (!chooser) {
      chooser = function (key, pres) {
        return pres as any;
      };
    }

    return this.map(presences, (key, presence) => {
      return chooser!(key, presence);
    });
  }

  // private

  private static map<T>(
    obj: PresenceMap,
    func: (key: string, presence: PresenceState) => T,
  ): T[] {
    return Object.getOwnPropertyNames(obj).map((key) => func(key, obj[key]!));
  }

  private static clone<T>(obj: T): T {
    return JSON.parse(JSON.stringify(obj));
  }
}
