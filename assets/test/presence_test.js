import assert from "assert"

import {Presence} from "../js/phoenix"

let clone = (obj) => { return JSON.parse(JSON.stringify(obj)) }

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

describe("syncState", () => {
  it("syncs empty state", () => {
    let newState = {u1: {metas: [{id: 1, phx_ref: "1"}]}}
    let state = {}
    let stateBefore = clone(state)
    Presence.syncState(state, newState)
    assert.deepEqual(state, stateBefore)

    state = Presence.syncState(state, newState)
    assert.deepEqual(state, newState)
  })

  it("onJoins new presences and onLeave's left presences", () => {
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
    let stateBefore = clone(state)
    Presence.syncState(state, newState, onJoin, onLeave)
    assert.deepEqual(state, stateBefore)

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

  it("onJoins only newly added metas", () => {
    let newState = {u3: {metas: [{id: 3, phx_ref: "3"}, {id: 3, phx_ref: "3.new"}]}}
    let state = {u3: {metas: [{id: 3, phx_ref: "3"}]}}
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
      u3: {current: {metas: [{id: 3, phx_ref: "3"}]},
           newPres: {metas: [{id: 3, phx_ref: "3"}, {id: 3, phx_ref: "3.new"}]}}
    })
    assert.deepEqual(left, {})
  })
})

describe("syncDiff", () => {
  it("syncs empty state", () => {
    let joins = {u1: {metas: [{id: 1, phx_ref: "1"}]}}
    let state = {}
    Presence.syncDiff(state, {joins: joins, leaves: {}})
    assert.deepEqual(state, {})

    state = Presence.syncDiff(state, {
      joins: joins,
      leaves: {}
    })
    assert.deepEqual(state, joins)
  })

  it("removes presence when meta is empty and adds additional meta", () => {
    let state = fixtures.state()
    state = Presence.syncDiff(state, {joins: fixtures.joins(), leaves: fixtures.leaves()})

    assert.deepEqual(state, {
      u1: {metas: [{id: 1, phx_ref: "1"}, {id: 1, phx_ref: "1.2"}]},
      u3: {metas: [{id: 3, phx_ref: "3"}]}
    })
  })

  it("removes meta while leaving key if other metas exist", () => {
    let state = {
      u1: {metas: [{id: 1, phx_ref: "1"}, {id: 1, phx_ref: "1.2"}]}
    }
    state = Presence.syncDiff(state, {joins: {}, leaves: {u1: {metas: [{id: 1, phx_ref: "1"}]}}})

    assert.deepEqual(state, {
      u1: {metas: [{id: 1, phx_ref: "1.2"}]},
    })
  })
})


describe("list", () => {
  it("lists full presence by default", () => {
    let state = fixtures.state()
    assert.deepEqual(Presence.list(state), [
      {metas: [{id: 1, phx_ref: "1"}]},
      {metas: [{id: 2, phx_ref: "2"}]},
      {metas: [{id: 3, phx_ref: "3"}]}
    ])
  })

  it("lists with custom function", () => {
    let state = {u1: {metas: [
      {id: 1, phx_ref: "1.first"},
      {id: 1, phx_ref: "1.second"}]
    }}

    let listBy = (key, {metas: [first, ...rest]}) => {
      return first
    }

    assert.deepEqual(Presence.list(state, listBy), [
      {id: 1, phx_ref: "1.first"}
    ])
  })
})