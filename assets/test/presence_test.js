import {Presence} from "../js/phoenix"

const clone = (obj) => {
  let cloned = JSON.parse(JSON.stringify(obj))
  Object.entries(obj).forEach(([key, val]) => {
    if(val === undefined){
      cloned[key] = undefined
    }
  })
  return cloned
}

const fixtures = {
  joins(){
    return {u1: {metas: [{id: 1, phx_ref: "1.2"}]}}
  },
  leaves(){
    return {u2: {metas: [{id: 2, phx_ref: "2"}]}}
  },
  state(){
    return {
      u1: {metas: [{id: 1, phx_ref: "1"}]},
      u2: {metas: [{id: 2, phx_ref: "2"}]},
      u3: {metas: [{id: 3, phx_ref: "3"}]},
    }
  },
}

const channelStub = {
  ref: 1,
  events: {},

  on(event, callback){
    this.events[event] = callback
  },

  trigger(event, data){
    this.events[event](data)
  },

  joinRef(){
    return `${this.ref}`
  },

  simulateDisconnectAndReconnect(){
    this.ref++
  },
}

const listByFirst = (id, {metas: [first, ..._rest]}) => first

describe("syncState", () => {
  it("syncs empty state", () => {
    let newState = {u1: {metas: [{id: 1, phx_ref: "1"}]}}
    let state = {}
    let stateBefore = clone(state)
    Presence.syncState(state, newState)
    expect(state).toEqual(stateBefore)

    state = Presence.syncState(state, newState)
    expect(state).toEqual(newState)
  })

  it("onJoins new presences and onLeave's left presences", () => {
    let newState = fixtures.state()
    let state = {u4: {metas: [{id: 4, phx_ref: "4"}]}}
    let joined = {}
    let left = {}
    const onJoin = (key, current, newPres) => {
      joined[key] = {current, newPres}
    }
    const onLeave = (key, current, leftPres) => {
      left[key] = {current, leftPres}
    }

    state = Presence.syncState(state, newState, onJoin, onLeave)
    expect(state).toEqual(newState)
    expect(joined).toEqual({
      u1: {current: undefined, newPres: {metas: [{id: 1, phx_ref: "1"}]}},
      u2: {current: undefined, newPres: {metas: [{id: 2, phx_ref: "2"}]}},
      u3: {current: undefined, newPres: {metas: [{id: 3, phx_ref: "3"}]}},
    })
    expect(left).toEqual({
      u4: {current: {metas: []}, leftPres: {metas: [{id: 4, phx_ref: "4"}]}},
    })
  })

  it("onJoins only newly added metas", () => {
    let newState = {u3: {metas: [{id: 3, phx_ref: "3"}, {id: 3, phx_ref: "3.new"}]}}
    let state = {u3: {metas: [{id: 3, phx_ref: "3"}]}}
    let joined = []
    let left = []
    const onJoin = (key, current, newPres) => {
      joined.push([key, clone({current, newPres})])
    }
    const onLeave = (key, current, leftPres) => {
      left.push([key, clone({current, leftPres})])
    }
    state = Presence.syncState(state, clone(newState), onJoin, onLeave)
    expect(state).toEqual(newState)
    expect(joined).toEqual([
      ["u3", {current: {metas: [{id: 3, phx_ref: "3"}]}, newPres: {metas: [{id: 3, phx_ref: "3.new"}]}}],
    ])
    expect(left).toEqual([])
  })
})

describe("syncDiff", () => {
  it("syncs empty state", () => {
    let joins = {u1: {metas: [{id: 1, phx_ref: "1"}]}}
    let state = Presence.syncDiff({}, {joins, leaves: {}})
    expect(state).toEqual(joins)
  })

  it("removes presence when meta is empty and adds additional meta", () => {
    let state = fixtures.state()
    state = Presence.syncDiff(state, {joins: fixtures.joins(), leaves: fixtures.leaves()})

    expect(state).toEqual({
      u1: {metas: [{id: 1, phx_ref: "1"}, {id: 1, phx_ref: "1.2"}]},
      u3: {metas: [{id: 3, phx_ref: "3"}]},
    })
  })

  it("removes meta while leaving key if other metas exist", () => {
    let state = {u1: {metas: [{id: 1, phx_ref: "1"}, {id: 1, phx_ref: "1.2"}]}}
    state = Presence.syncDiff(state, {joins: {}, leaves: {u1: {metas: [{id: 1, phx_ref: "1"}]}}})

    expect(state).toEqual({
      u1: {metas: [{id: 1, phx_ref: "1.2"}]},
    })
  })
})

describe("list", () => {
  it("lists full presence by default", () => {
    let state = fixtures.state()
    expect(Presence.list(state)).toEqual([
      {metas: [{id: 1, phx_ref: "1"}]},
      {metas: [{id: 2, phx_ref: "2"}]},
      {metas: [{id: 3, phx_ref: "3"}]},
    ])
  })

  it("lists with custom function", () => {
    let state = {u1: {metas: [{id: 1, phx_ref: "1.first"}, {id: 1, phx_ref: "1.second"}]}}

    const listBy = (key, {metas: [first, ..._rest]}) => first

    expect(Presence.list(state, listBy)).toEqual([{id: 1, phx_ref: "1.first"}])
  })
})

describe("instance", () => {
  it("syncs state and diffs", () => {
    let presence = new Presence(channelStub)
    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    let user2 = {metas: [{id: 2, phx_ref: "2"}]}
    let newState = {u1: user1, u2: user2}

    channelStub.trigger("presence_state", newState)
    expect(presence.list(listByFirst)).toEqual([{id: 1, phx_ref: "1"}, {id: 2, phx_ref: "2"}])

    channelStub.trigger("presence_diff", {joins: {}, leaves: {u1: user1}})
    expect(presence.list(listByFirst)).toEqual([{id: 2, phx_ref: "2"}])
  })

  it("applies pending diff if state is not yet synced", () => {
    let presence = new Presence(channelStub)
    let onJoins = []
    let onLeaves = []

    presence.onJoin((id, current, newPres) => {
      onJoins.push(clone({id, current, newPres}))
    })
    presence.onLeave((id, current, leftPres) => {
      onLeaves.push(clone({id, current, leftPres}))
    })

    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    let user2 = {metas: [{id: 2, phx_ref: "2"}]}
    let user3 = {metas: [{id: 3, phx_ref: "3"}]}
    let newState = {u1: user1, u2: user2}
    let leaves = {u2: user2}

    channelStub.trigger("presence_diff", {joins: {}, leaves: leaves})

    expect(presence.list(listByFirst)).toEqual([])
    expect(presence.pendingDiffs).toEqual([{joins: {}, leaves: leaves}])

    channelStub.trigger("presence_state", newState)
    expect(onLeaves).toEqual([{id: "u2", current: {metas: []}, leftPres: {metas: [{id: 2, phx_ref: "2"}]}}])

    expect(presence.list(listByFirst)).toEqual([{id: 1, phx_ref: "1"}])
    expect(presence.pendingDiffs).toEqual([])
    expect(onJoins).toEqual([
      {id: "u1", current: undefined, newPres: {metas: [{id: 1, phx_ref: "1"}]}},
      {id: "u2", current: undefined, newPres: {metas: [{id: 2, phx_ref: "2"}]}},
    ])

    channelStub.simulateDisconnectAndReconnect()
    expect(presence.inPendingSyncState()).toBe(true)

    channelStub.trigger("presence_diff", {joins: {}, leaves: {u1: user1}})
    expect(presence.list(listByFirst)).toEqual([{id: 1, phx_ref: "1"}])

    channelStub.trigger("presence_state", {u1: user1, u3: user3})
    expect(presence.list(listByFirst)).toEqual([{id: 3, phx_ref: "3"}])
  })

  it("allows custom channel events", () => {
    let presence = new Presence(channelStub, {
      events: {
        state: "the_state",
        diff: "the_diff",
      },
    })

    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    channelStub.trigger("the_state", {user1})
    expect(presence.list(listByFirst)).toEqual([{id: 1, phx_ref: "1"}])
    channelStub.trigger("the_diff", {joins: {}, leaves: {user1}})
    expect(presence.list(listByFirst)).toEqual([])
  })

  it("updates existing meta for a presence update (leave + join)", () => {
    let presence = new Presence(channelStub)
    let onJoins = []
    let onLeaves = []

    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    let user2 = {metas: [{id: 2, name: "chris", phx_ref: "2"}]}
    let newState = {u1: user1, u2: user2}

    channelStub.trigger("presence_state", clone(newState))

    presence.onJoin((id, current, newPres) => {
      onJoins.push(clone({id, current, newPres}))
    })
    presence.onLeave((id, current, leftPres) => {
      onLeaves.push(clone({id, current, leftPres}))
    })

    expect(presence.list((id, {metas: metas}) => metas)).toEqual([
      [{id: 1, phx_ref: "1"}],
      [{id: 2, name: "chris", phx_ref: "2"}],
    ])

    let leaves = {u2: user2}
    let joins = {u2: {metas: [{id: 2, name: "chris.2", phx_ref: "2.2", phx_ref_prev: "2"}]}}
    channelStub.trigger("presence_diff", {joins, leaves})

    expect(presence.list((id, {metas: metas}) => metas)).toEqual([
      [{id: 1, phx_ref: "1"}],
      [{id: 2, name: "chris.2", phx_ref: "2.2", phx_ref_prev: "2"}],
    ])

    expect(onJoins).toEqual([
      {
        id: "u2",
        current: {metas: [{id: 2, name: "chris", phx_ref: "2"}]},
        newPres: {metas: [{id: 2, name: "chris.2", phx_ref: "2.2", phx_ref_prev: "2"}]},
      },
    ])
  })
})
