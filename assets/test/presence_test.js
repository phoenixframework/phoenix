import assert from "assert"

import {Presence} from "../js/phoenix"

let clone = (obj) => {
  let cloned = JSON.parse(JSON.stringify(obj))
  Object.entries(obj).map(([key, val]) => {
    if(val === undefined){ cloned[key] = undefined }
  })
  return cloned
}

let fixtures = {
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
      u3: {metas: [{id: 3, phx_ref: "3"}]}
    }
  }
}

let channelStub = {
  ref: 1,
  events: {},

  on(event, callback){ 
    this.events[event] = callback
    return `${event}-ref`
  },

  off(event, ref){
    if(ref && ref !== `${event}-ref`) throw new Error("invalid ref")
    this.events[event] = function(){}
  },

  trigger(event, data){ this.events[event](data) },

  joinRef(){ return `${this.ref}` },

  simulateDisconnectAndReconnect(){
    this.ref++
  }
}

let listByFirst = (id, {metas: [first, ..._rest]}) => first

describe("syncState", function(){
  it("syncs empty state", function(){
    let newState = {u1: {metas: [{id: 1, phx_ref: "1"}]}}
    let state = {}
    let stateBefore = clone(state)
    Presence.syncState(state, newState)
    assert.deepEqual(state, stateBefore)

    state = Presence.syncState(state, newState)
    assert.deepEqual(state, newState)
  })

  it("onJoins new presences and onLeave's left presences", function(){
    let newState = fixtures.state()
    let state = {u4: {metas: [{id: 4, phx_ref: "4"}]}}
    let joined = {}
    let left = {}
    let onJoin = (key, current, newPres) => {
      joined[key] = {current: current, newPres: newPres}
    }
    let onLeave = (key, current, leftPres) => {
      left[key] = {current: current, leftPres: leftPres}
    }

    state = Presence.syncState(state, newState, onJoin, onLeave)
    assert.deepEqual(state, newState)
    assert.deepEqual(joined, {
      u1: {current: null, newPres: {metas: [{id: 1, phx_ref: "1"}]}},
      u2: {current: null, newPres: {metas: [{id: 2, phx_ref: "2"}]}},
      u3: {current: null, newPres: {metas: [{id: 3, phx_ref: "3"}]}}
    })
    assert.deepEqual(left, {
      u4: {current: {metas: []}, leftPres: {metas: [{id: 4, phx_ref: "4"}]}}
    })
  })

  it("onJoins only newly added metas", function(){
    let newState = {u3: {metas: [{id: 3, phx_ref: "3"}, {id: 3, phx_ref: "3.new"}]}}
    let state = {u3: {metas: [{id: 3, phx_ref: "3"}]}}
    let joined = []
    let left = []
    let onJoin = (key, current, newPres) => {
      joined.push([key, clone({current: current, newPres: newPres})])
    }
    let onLeave = (key, current, leftPres) => {
      left.push([key, clone({current: current, leftPres: leftPres})])
    }
    state = Presence.syncState(state, clone(newState), onJoin, onLeave)
    assert.deepEqual(state, newState)
    assert.deepEqual(joined, [
      ["u3", {current: {metas: [{id: 3, phx_ref: "3"}]},
        newPres: {metas: [{id: 3, phx_ref: "3.new"}]}}]
    ])
    assert.deepEqual(left, [])
  })
})

describe("syncDiff", function(){
  it("syncs empty state", function(){
    let joins = {u1: {metas: [{id: 1, phx_ref: "1"}]}}
    let state = Presence.syncDiff({}, {
      joins: joins,
      leaves: {}
    })
    assert.deepEqual(state, joins)
  })

  it("removes presence when meta is empty and adds additional meta", function(){
    let state = fixtures.state()
    state = Presence.syncDiff(state, {joins: fixtures.joins(), leaves: fixtures.leaves()})

    assert.deepEqual(state, {
      u1: {metas: [{id: 1, phx_ref: "1"}, {id: 1, phx_ref: "1.2"}]},
      u3: {metas: [{id: 3, phx_ref: "3"}]}
    })
  })

  it("removes meta while leaving key if other metas exist", function(){
    let state = {
      u1: {metas: [{id: 1, phx_ref: "1"}, {id: 1, phx_ref: "1.2"}]}
    }
    state = Presence.syncDiff(state, {joins: {}, leaves: {u1: {metas: [{id: 1, phx_ref: "1"}]}}})

    assert.deepEqual(state, {
      u1: {metas: [{id: 1, phx_ref: "1.2"}]},
    })
  })
})


describe("list", function(){
  it("lists full presence by default", function(){
    let state = fixtures.state()
    assert.deepEqual(Presence.list(state), [
      {metas: [{id: 1, phx_ref: "1"}]},
      {metas: [{id: 2, phx_ref: "2"}]},
      {metas: [{id: 3, phx_ref: "3"}]}
    ])
  })

  it("lists with custom function", function(){
    let state = {u1: {metas: [
      {id: 1, phx_ref: "1.first"},
      {id: 1, phx_ref: "1.second"}]
    }}

    let listBy = (key, {metas: [first, ..._rest]}) => {
      return first
    }

    assert.deepEqual(Presence.list(state, listBy), [
      {id: 1, phx_ref: "1.first"}
    ])
  })
})

describe("instance", function(){
  it("syncs state and diffs", function(){
    let presence = new Presence(channelStub)
    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    let user2 = {metas: [{id: 2, phx_ref: "2"}]}
    let newState = {u1: user1, u2: user2}

    channelStub.trigger("presence_state", newState)
    assert.deepEqual(presence.list(listByFirst), [{id: 1, phx_ref: 1},
      {id: 2, phx_ref: 2}])

    channelStub.trigger("presence_diff", {joins: {}, leaves: {u1: user1}})
    assert.deepEqual(presence.list(listByFirst), [{id: 2, phx_ref: 2}])
  })


  it("applies pending diff if state is not yet synced", function(){
    let presence = new Presence(channelStub)
    let onJoins = []
    let onLeaves = []

    presence.onJoin((id, current, newPres) => {
      onJoins.push(clone({id, current, newPres}))
    })
    presence.onLeave((id, current, leftPres) => {
      onLeaves.push(clone({id, current, leftPres}))
    })

    // new connection
    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    let user2 = {metas: [{id: 2, phx_ref: "2"}]}
    let user3 = {metas: [{id: 3, phx_ref: "3"}]}
    let newState = {u1: user1, u2: user2}
    let leaves = {u2: user2}

    channelStub.trigger("presence_diff", {joins: {}, leaves: leaves})

    assert.deepEqual(presence.list(listByFirst), [])
    assert.deepEqual(presence.pendingDiffs, [{joins: {}, leaves: leaves}])

    channelStub.trigger("presence_state", newState)
    assert.deepEqual(onLeaves, [
      {id: "u2", current: {metas: []}, leftPres: {metas: [{id: 2, phx_ref: "2"}]}}
    ])

    assert.deepEqual(presence.list(listByFirst), [{id: 1, phx_ref: "1"}])
    assert.deepEqual(presence.pendingDiffs, [])
    assert.deepEqual(onJoins, [
      {id: "u1", current: undefined, newPres: {metas: [{id: 1, phx_ref: "1"}]}},
      {id: "u2", current: undefined, newPres: {metas: [{id: 2, phx_ref: "2"}]}}
    ])

    // disconnect and reconnect
    assert.equal(presence.inPendingSyncState(), false)
    channelStub.simulateDisconnectAndReconnect()
    assert.equal(presence.inPendingSyncState(), true)

    channelStub.trigger("presence_diff", {joins: {}, leaves: {u1: user1}})
    assert.deepEqual(presence.list(listByFirst), [{id: 1, phx_ref: "1"}])

    channelStub.trigger("presence_state", {u1: user1, u3: user3})
    assert.deepEqual(presence.list(listByFirst), [{id: 3, phx_ref: "3"}])
  })

  it("allows custom channel events", function(){
    let presence = new Presence(channelStub, {events: {
      state: "the_state",
      diff: "the_diff"
    }})

    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    channelStub.trigger("the_state", {user1: user1})
    assert.deepEqual(presence.list(listByFirst), [{id: 1, phx_ref: "1"}])
    channelStub.trigger("the_diff", {joins: {}, leaves: {user1: user1}})
    assert.deepEqual(presence.list(listByFirst), [])
  })

  it("stops syncing after destroyed", function(){
    let presence = new Presence(channelStub)
    let user1 = {metas: [{id: 1, phx_ref: "1"}]}
    let user2 = {metas: [{id: 2, phx_ref: "2"}]}
    let newState = {u1: user1, u2: user2}

    channelStub.trigger("presence_state", newState)
    assert.deepEqual(presence.list(listByFirst), [{id: 1, phx_ref: 1},
      {id: 2, phx_ref: 2}])

    channelStub.trigger("presence_diff", {joins: {}, leaves: {u1: user1}})
    assert.deepEqual(presence.list(listByFirst), [{id: 2, phx_ref: 2}])

    presence.destroy()
    channelStub.trigger("presence_diff", {joins: {u1: user1}, leaves: {}})
    assert.deepEqual(presence.list(listByFirst), [{id: 2, phx_ref: 2}])
    channelStub.trigger("presence_diff", {joins: {}, leaves: {u2: user2}})
    assert.deepEqual(presence.list(listByFirst), [{id: 2, phx_ref: 2}])
  })

  it("updates existing meta for a presence update (leave + join)", function(){
    let presence = new Presence(channelStub)
    let onJoins = []
    let onLeaves = []

    // new connection
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

    assert.deepEqual(presence.list((id, {metas: metas}) => metas),
      [
        [
          {
            "id": 1,
            "phx_ref": "1"
          }
        ],
        [
          {
            "id": 2,
            "name": "chris",
            "phx_ref": "2"
          }
        ]
      ]
    )

    let leaves = {u2: user2}
    let joins = {u2: {metas: [{id: 2, name: "chris.2", phx_ref: "2.2", phx_ref_prev: "2"}]}}
    channelStub.trigger("presence_diff", {joins: joins, leaves: leaves})

    assert.deepEqual(presence.list((id, {metas: metas}) => metas),
      [
        [
          {
            id: 1,
            phx_ref: '1'
          }
        ],
        [
          {
            id: 2,
            name: 'chris.2',
            phx_ref: '2.2',
            phx_ref_prev: '2'
          }
        ]
      ]
    )

    assert.deepEqual(onJoins,
      [
        {
          "current": {
            "metas": [
              {
                "id": 2,
                "name": "chris",
                "phx_ref": "2"
              }
            ]
          },
          "id": "u2",
          "newPres": {
            "metas": [
              {
                "id": 2,
                "name": "chris.2",
                "phx_ref": "2.2",
                "phx_ref_prev": "2"
              }
            ]
          }
        }
      ]
    )
  })
})
