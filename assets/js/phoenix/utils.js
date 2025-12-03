/**
*
* Wraps value in closure or returns closure
*
* @template T
* @param {T | (() => T)} value
* @returns {() => T}
*/
export let closure = (value) => {
  if(typeof value === "function"){
    return /** @type {() => T} */ (value)
  } else {
    let closure = function (){ return value }
    return closure
  }
}
