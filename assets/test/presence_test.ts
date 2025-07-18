import {
  default as Presence,
  type PresenceMap,
  type PresenceMeta,
} from "../js/phoenix/presence";

interface Meta extends PresenceMeta {
  id: number;
  name?: string;
  phx_ref_prev?: string;
}

const clone = (obj: any): any => {
  const cloned = JSON.parse(JSON.stringify(obj));
  Object.entries(obj).forEach(([key, val]) => {
    if (val === undefined) {
      cloned[key] = undefined;
    }
  });
  return cloned;
};

const fixtures = {
  joins(): PresenceMap {
    return { u1: { metas: [{ id: 1, phx_ref: "1.2" }] } };
  },
  leaves(): PresenceMap {
    return { u2: { metas: [{ id: 2, phx_ref: "2" }] } };
  },
  state(): PresenceMap {
    return {
      u1: { metas: [{ id: 1, phx_ref: "1" }] },
      u2: { metas: [{ id: 2, phx_ref: "2" }] },
      u3: { metas: [{ id: 3, phx_ref: "3" }] },
    };
  },
};

interface ChannelStub {
  ref: number;
  events: { [key: string]: (data: any) => void };
  on(event: string, callback: (data: any) => void): void;
  trigger(event: string, data: any): void;
  joinRef(): string;
  simulateDisconnectAndReconnect(): void;
}

const channelStub: ChannelStub = {
  ref: 1,
  events: {},

  on(event: string, callback: (data: any) => void) {
    this.events[event] = callback;
  },

  trigger(event: string, data: any) {
    this.events[event](data);
  },

  joinRef(): string {
    return `${this.ref}`;
  },

  simulateDisconnectAndReconnect() {
    this.ref++;
  },
};

const listByFirst = (
  id: string,
  { metas: [first, ..._rest] }: { metas: Meta[] },
): Meta => first;

describe("syncState", () => {
  it("syncs empty state", () => {
    const newState = { u1: { metas: [{ id: 1, phx_ref: "1" }] } };
    let state = {};
    const stateBefore = clone(state);
    Presence.syncState(state, newState);
    expect(state).toEqual(stateBefore);

    state = Presence.syncState(state, newState);
    expect(state).toEqual(newState);
  });

  it("onJoins new presences and onLeave's left presences", () => {
    const newState = fixtures.state();
    let state: PresenceMap = { u4: { metas: [{ id: 4, phx_ref: "4" }] } };
    const joined: any = {};
    const left: any = {};
    const onJoin = (key: string, current: any, newPres: any) => {
      joined[key] = { current, newPres };
    };
    const onLeave = (key: string, current: any, leftPres: any) => {
      left[key] = { current, leftPres };
    };

    state = Presence.syncState(state, newState, onJoin, onLeave);
    expect(state).toEqual(newState);
    expect(joined).toEqual({
      u1: { current: undefined, newPres: { metas: [{ id: 1, phx_ref: "1" }] } },
      u2: { current: undefined, newPres: { metas: [{ id: 2, phx_ref: "2" }] } },
      u3: { current: undefined, newPres: { metas: [{ id: 3, phx_ref: "3" }] } },
    });
    expect(left).toEqual({
      u4: {
        current: { metas: [] },
        leftPres: { metas: [{ id: 4, phx_ref: "4" }] },
      },
    });
  });

  it("onJoins only newly added metas", () => {
    const newState = {
      u3: {
        metas: [
          { id: 3, phx_ref: "3" },
          { id: 3, phx_ref: "3.new" },
        ],
      },
    };
    let state: PresenceMap = { u3: { metas: [{ id: 3, phx_ref: "3" }] } };
    const joined: any[] = [];
    const left: any[] = [];
    const onJoin = (key: string, current: any, newPres: any) => {
      joined.push([key, clone({ current, newPres })]);
    };
    const onLeave = (key: string, current: any, leftPres: any) => {
      left.push([key, clone({ current, leftPres })]);
    };
    state = Presence.syncState(state, clone(newState), onJoin, onLeave);
    expect(state).toEqual(newState);
    expect(joined).toEqual([
      [
        "u3",
        {
          current: { metas: [{ id: 3, phx_ref: "3" }] },
          newPres: { metas: [{ id: 3, phx_ref: "3.new" }] },
        },
      ],
    ]);
    expect(left).toEqual([]);
  });
});

describe("syncDiff", () => {
  it("syncs empty state", () => {
    const joins = { u1: { metas: [{ id: 1, phx_ref: "1" }] } };
    const state = Presence.syncDiff({}, { joins, leaves: {} });
    expect(state).toEqual(joins);
  });

  it("removes presence when meta is empty and adds additional meta", () => {
    let state = fixtures.state();
    state = Presence.syncDiff(state, {
      joins: fixtures.joins(),
      leaves: fixtures.leaves(),
    });

    expect(state).toEqual({
      u1: {
        metas: [
          { id: 1, phx_ref: "1" },
          { id: 1, phx_ref: "1.2" },
        ],
      },
      u3: { metas: [{ id: 3, phx_ref: "3" }] },
    });
  });

  it("removes meta while leaving key if other metas exist", () => {
    let state: PresenceMap = {
      u1: {
        metas: [
          { id: 1, phx_ref: "1" },
          { id: 1, phx_ref: "1.2" },
        ],
      },
    };
    state = Presence.syncDiff(state, {
      joins: {},
      leaves: { u1: { metas: [{ id: 1, phx_ref: "1" }] } },
    });

    expect(state).toEqual({
      u1: { metas: [{ id: 1, phx_ref: "1.2" }] },
    });
  });
});

describe("list", () => {
  it("lists full presence by default", () => {
    const state = fixtures.state();
    expect(Presence.list(state)).toEqual([
      { metas: [{ id: 1, phx_ref: "1" }] },
      { metas: [{ id: 2, phx_ref: "2" }] },
      { metas: [{ id: 3, phx_ref: "3" }] },
    ]);
  });

  it("lists with custom function", () => {
    const state = {
      u1: {
        metas: [
          { id: 1, phx_ref: "1.first" },
          { id: 1, phx_ref: "1.second" },
        ],
      },
    };

    const listBy = (
      key: string,
      { metas: [first, ..._rest] }: { metas: Meta[] },
    ): Meta => first;

    expect(Presence.list(state, listBy)).toEqual([
      { id: 1, phx_ref: "1.first" },
    ]);
  });
});

describe("instance", () => {
  it("syncs state and diffs", () => {
    const presence = new Presence(channelStub as any);
    const user1 = { metas: [{ id: 1, phx_ref: "1" }] };
    const user2 = { metas: [{ id: 2, phx_ref: "2" }] };
    const newState = { u1: user1, u2: user2 };

    channelStub.trigger("presence_state", newState);
    expect(presence.list(listByFirst)).toEqual([
      { id: 1, phx_ref: "1" },
      { id: 2, phx_ref: "2" },
    ]);

    channelStub.trigger("presence_diff", { joins: {}, leaves: { u1: user1 } });
    expect(presence.list(listByFirst)).toEqual([{ id: 2, phx_ref: "2" }]);
  });

  it("applies pending diff if state is not yet synced", () => {
    const presence = new Presence(channelStub as any);
    const onJoins: any[] = [];
    const onLeaves: any[] = [];

    presence.onJoin((id: string, current: any, newPres: any) => {
      onJoins.push(clone({ id, current, newPres }));
    });
    presence.onLeave((id: string, current: any, leftPres: any) => {
      onLeaves.push(clone({ id, current, leftPres }));
    });

    const user1 = { metas: [{ id: 1, phx_ref: "1" }] };
    const user2 = { metas: [{ id: 2, phx_ref: "2" }] };
    const user3 = { metas: [{ id: 3, phx_ref: "3" }] };
    const newState = { u1: user1, u2: user2 };
    const leaves = { u2: user2 };

    channelStub.trigger("presence_diff", { joins: {}, leaves: leaves });

    expect(presence.list(listByFirst)).toEqual([]);
    expect(presence["pendingDiffs"]).toEqual([{ joins: {}, leaves: leaves }]);

    channelStub.trigger("presence_state", newState);
    expect(onLeaves).toEqual([
      {
        id: "u2",
        current: { metas: [] },
        leftPres: { metas: [{ id: 2, phx_ref: "2" }] },
      },
    ]);

    expect(presence.list(listByFirst)).toEqual([{ id: 1, phx_ref: "1" }]);
    expect(presence["pendingDiffs"]).toEqual([]);
    expect(onJoins).toEqual([
      {
        id: "u1",
        current: undefined,
        newPres: { metas: [{ id: 1, phx_ref: "1" }] },
      },
      {
        id: "u2",
        current: undefined,
        newPres: { metas: [{ id: 2, phx_ref: "2" }] },
      },
    ]);

    channelStub.simulateDisconnectAndReconnect();
    expect(presence.inPendingSyncState()).toBe(true);

    channelStub.trigger("presence_diff", { joins: {}, leaves: { u1: user1 } });
    expect(presence.list(listByFirst)).toEqual([{ id: 1, phx_ref: "1" }]);

    channelStub.trigger("presence_state", { u1: user1, u3: user3 });
    expect(presence.list(listByFirst)).toEqual([{ id: 3, phx_ref: "3" }]);
  });

  it("allows custom channel events", () => {
    const presence = new Presence(channelStub as any, {
      events: {
        state: "the_state",
        diff: "the_diff",
      },
    });

    const user1 = { metas: [{ id: 1, phx_ref: "1" }] };
    channelStub.trigger("the_state", { user1 });
    expect(presence.list(listByFirst)).toEqual([{ id: 1, phx_ref: "1" }]);
    channelStub.trigger("the_diff", { joins: {}, leaves: { user1 } });
    expect(presence.list(listByFirst)).toEqual([]);
  });

  it("updates existing meta for a presence update (leave + join)", () => {
    const presence = new Presence(channelStub as any);
    const onJoins: any[] = [];
    const onLeaves: any[] = [];

    const user1 = { metas: [{ id: 1, phx_ref: "1" }] };
    const user2 = { metas: [{ id: 2, name: "chris", phx_ref: "2" }] };
    const newState = { u1: user1, u2: user2 };

    channelStub.trigger("presence_state", clone(newState));

    presence.onJoin((id: string, current: any, newPres: any) => {
      onJoins.push(clone({ id, current, newPres }));
    });
    presence.onLeave((id: string, current: any, leftPres: any) => {
      onLeaves.push(clone({ id, current, leftPres }));
    });

    expect(
      presence.list((id: string, { metas }: { metas: Meta[] }) => metas),
    ).toEqual([
      [{ id: 1, phx_ref: "1" }],
      [{ id: 2, name: "chris", phx_ref: "2" }],
    ]);

    const leaves = { u2: user2 };
    const joins = {
      u2: {
        metas: [{ id: 2, name: "chris.2", phx_ref: "2.2", phx_ref_prev: "2" }],
      },
    };
    channelStub.trigger("presence_diff", { joins, leaves });

    expect(
      presence.list((id: string, { metas }: { metas: Meta[] }) => metas),
    ).toEqual([
      [{ id: 1, phx_ref: "1" }],
      [{ id: 2, name: "chris.2", phx_ref: "2.2", phx_ref_prev: "2" }],
    ]);

    expect(onJoins).toEqual([
      {
        id: "u2",
        current: { metas: [{ id: 2, name: "chris", phx_ref: "2" }] },
        newPres: {
          metas: [
            { id: 2, name: "chris.2", phx_ref: "2.2", phx_ref_prev: "2" },
          ],
        },
      },
    ]);
  });
});
