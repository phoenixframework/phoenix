 static syncState(currentState, newState, onJoin, onLeave) {
  let state = this.clone(currentState);
  let joins = {};
  let leaves = {};

  // Identify leaves
  this.map(state, (key, presence) => {
    if (!newState[key]) {
      leaves[key] = presence;
    }
  });

  // Identify joins and metadata changes
  this.map(newState, (key, newPresence) => {
    let currentPresence = state[key];
    if (currentPresence) {
      let newRefs = newPresence.metas.map((m) => m.phx_ref);
      let curRefs = currentPresence.metas.map((m) => m.phx_ref);
      let joinedMetas = newPresence.metas.filter((m) => curRefs.indexOf(m.phx_ref) < 0);
      let leftMetas = currentPresence.metas.filter((m) => newRefs.indexOf(m.phx_ref) < 0);

      if (joinedMetas.length > 0) {
        joins[key] = this.clone(newPresence);
        joins[key].metas = joinedMetas; // Only new metas
      }
      if (leftMetas.length > 0) {
        leaves[key] = this.clone(currentPresence);
        leaves[key].metas = leftMetas; // Only left metas
      }
    } else {
      joins[key] = newPresence; // Completely new presence
    }
  });

  return this.syncDiff(state, { joins: joins, leaves: leaves }, onJoin, onLeave);
}

static syncDiff(state, diff, onJoin, onLeave) {
  let { joins, leaves } = this.clone(diff);
  if (!onJoin) onJoin = () => {};
  if (!onLeave) onLeave = () => {};

  // Process joins
  this.map(joins, (key, newPresence) => {
    let currentPresence = state[key];
    state[key] = this.clone(newPresence);

    if (currentPresence) {
      let joinedRefs = state[key].metas.map((m) => m.phx_ref);
      let curMetas = currentPresence.metas.filter((m) => joinedRefs.indexOf(m.phx_ref) < 0);
      state[key].metas.unshift(...curMetas);
    }

    // Call onJoin with metadata
    onJoin(key, currentPresence, newPresence);
  });

  // Process leaves
  this.map(leaves, (key, leftPresence) => {
    let currentPresence = state[key];
    if (!currentPresence) return;

    let refsToRemove = leftPresence.metas.map((m) => m.phx_ref);
    currentPresence.metas = currentPresence.metas.filter((p) => refsToRemove.indexOf(p.phx_ref) < 0);

    onLeave(key, currentPresence, leftPresence);

    if (currentPresence.metas.length === 0) {
      delete state[key];
    }
  });

  return state;
}
