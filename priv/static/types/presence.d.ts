/**
 * @import Channel from "./channel"
 * @import { PresenceEvents, PresenceOnJoin, PresenceOnLeave, PresenceOnSync, PresenceState, PresenceDiff, PresenceOptions } from "./types"
 */
export default class Presence {
    /**
     * Used to sync the list of presences on the server
     * with the client's state. An optional `onJoin` and `onLeave` callback can
     * be provided to react to changes in the client's local presences across
     * disconnects and reconnects with the server.
     *
     * @param {Record<string, PresenceState>} currentState
     * @param {Record<string, PresenceState>} newState
     * @param {PresenceOnJoin} onJoin
     * @param {PresenceOnLeave} onLeave
     *
     * @returns {Record<string, PresenceState>}
     */
    static syncState(currentState: Record<string, PresenceState>, newState: Record<string, PresenceState>, onJoin: PresenceOnJoin, onLeave: PresenceOnLeave): Record<string, PresenceState>;
    /**
     *
     * Used to sync a diff of presence join and leave
     * events from the server, as they happen. Like `syncState`, `syncDiff`
     * accepts optional `onJoin` and `onLeave` callbacks to react to a user
     * joining or leaving from a device.
     *
     * @param {Record<string, PresenceState>} state
     * @param {PresenceDiff} diff
     * @param {PresenceOnJoin} onJoin
     * @param {PresenceOnLeave} onLeave
     *
     * @returns {Record<string, PresenceState>}
     */
    static syncDiff(state: Record<string, PresenceState>, diff: PresenceDiff, onJoin: PresenceOnJoin, onLeave: PresenceOnLeave): Record<string, PresenceState>;
    /**
     * Returns the array of presences, with selected metadata.
     *
     * @template [T=PresenceState]
     * @param {Record<string, PresenceState>} presences
     * @param {((key: string, obj: PresenceState) => T)} [chooser]
     *
     * @returns {T[]}
     */
    static list<T = PresenceState>(presences: Record<string, PresenceState>, chooser?: ((key: string, obj: PresenceState) => T)): T[];
    /**
    * @template T
    * @param {Record<string, PresenceState>} obj
    * @param {(key: string, obj: PresenceState) => T} func
    */
    static map<T>(obj: Record<string, PresenceState>, func: (key: string, obj: PresenceState) => T): T[];
    /**
    * @template T
    * @param {T} obj
    * @returns {T}
    */
    static clone<T>(obj: T): T;
    /**
     * Initializes the Presence
     * @param {Channel} channel - The Channel
     * @param {PresenceOptions} [opts] - The options, for example `{events: {state: "state", diff: "diff"}}`
     */
    constructor(channel: Channel, opts?: PresenceOptions);
    /** @type{Record<string, PresenceState>} */
    state: Record<string, PresenceState>;
    /** @type{PresenceDiff[]} */
    pendingDiffs: PresenceDiff[];
    /** @type{Channel} */
    channel: Channel;
    /** @type{?number} */
    joinRef: number | null;
    /** @type{({ onJoin: PresenceOnJoin; onLeave: PresenceOnLeave; onSync: PresenceOnSync })} */
    caller: ({
        onJoin: PresenceOnJoin;
        onLeave: PresenceOnLeave;
        onSync: PresenceOnSync;
    });
    /**
     * @param {PresenceOnJoin} callback
     */
    onJoin(callback: PresenceOnJoin): void;
    /**
     * @param {PresenceOnLeave} callback
     */
    onLeave(callback: PresenceOnLeave): void;
    /**
     * @param {PresenceOnSync} callback
     */
    onSync(callback: PresenceOnSync): void;
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
import type { PresenceState } from "./types";
import type { PresenceDiff } from "./types";
import type Channel from "./channel";
import type { PresenceOnJoin } from "./types";
import type { PresenceOnLeave } from "./types";
import type { PresenceOnSync } from "./types";
import type { PresenceOptions } from "./types";
//# sourceMappingURL=presence.d.ts.map