/**
 * @import Channel from "./channel"
 * @import { Events, OnJoin, OnLeave, OnSync, State, Diff, PresenceState } from "./types"
 */
export default class Presence {
    /**
     * Used to sync the list of presences on the server
     * with the client's state. An optional `onJoin` and `onLeave` callback can
     * be provided to react to changes in the client's local presences across
     * disconnects and reconnects with the server.
     *
     * @param {State} currentState
     * @param {State} newState
     * @param {OnJoin} onJoin
     * @param {OnLeave} onLeave
     *
     * @returns {State}
     */
    static syncState(currentState: State, newState: State, onJoin: OnJoin, onLeave: OnLeave): State;
    /**
     *
     * Used to sync a diff of presence join and leave
     * events from the server, as they happen. Like `syncState`, `syncDiff`
     * accepts optional `onJoin` and `onLeave` callbacks to react to a user
     * joining or leaving from a device.
     *
     * @param {State} state
     * @param {Diff} diff
     * @param {OnJoin} onJoin
     * @param {OnLeave} onLeave
     *
     * @returns {State}
     */
    static syncDiff(state: State, diff: Diff, onJoin: OnJoin, onLeave: OnLeave): State;
    /**
     * Returns the array of presences, with selected metadata.
     *
     * @template [T=PresenceState]
     * @param {State} presences
     * @param {((key: string, obj: Presence) => T)} [chooser]
     *
     * @returns {T[]}
     */
    static list<T = PresenceState>(presences: State, chooser?: ((key: string, obj: Presence) => T)): T[];
    /**
    * @template T
    * @param {State} obj
    * @param {(key: string, obj: PresenceState) => T} func
    */
    static map<T>(obj: State, func: (key: string, obj: PresenceState) => T): T[];
    /**
    * @template T
    * @param {T} obj
    * @returns {T}
    */
    static clone<T>(obj: T): T;
    /**
     * Initializes the Presence
     * @param {Channel} channel - The Channel
     * @param {{events?: Events}} [opts] - The options,
     *        for example `{events: {state: "state", diff: "diff"}}`
     */
    constructor(channel: Channel, opts?: {
        events?: Events;
    });
    /** @type{State} */
    state: State;
    /** @type{Diff[]} */
    pendingDiffs: Diff[];
    /** @type{Channel} */
    channel: Channel;
    /** @type{?number} */
    joinRef: number | null;
    /** @type{({ onJoin: OnJoin; onLeave: OnLeave; onSync: OnSync })} */
    caller: ({
        onJoin: OnJoin;
        onLeave: OnLeave;
        onSync: OnSync;
    });
    /**
     * @param {OnJoin} callback
     */
    onJoin(callback: OnJoin): void;
    /**
     * @param {OnLeave} callback
     */
    onLeave(callback: OnLeave): void;
    /**
     * @param {OnSync} callback
     */
    onSync(callback: OnSync): void;
    /**
     * Returns the array of presences, with selected metadata.
     *
     * @template [T=PresenceState]
     * @param {((key: string, obj: PresenceState) => T)} [by]
     *
     * @returns {T[]}
     */
    list<T = PresenceState>(by?: ((key: string, obj: PresenceState) => T)): T[];
    inPendingSyncState(): boolean;
}
import type { State } from "./types";
import type { Diff } from "./types";
import type Channel from "./channel";
import type { OnJoin } from "./types";
import type { OnLeave } from "./types";
import type { OnSync } from "./types";
import type { PresenceState } from "./types";
import type { Events } from "./types";
//# sourceMappingURL=presence.d.ts.map