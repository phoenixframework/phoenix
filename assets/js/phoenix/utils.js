// wraps value in closure or returns closure
export let closure = (value) => {
  if(typeof value === "function"){
    return value
  } else {
    let closure = function (){ return value }
    return closure
  }
}
