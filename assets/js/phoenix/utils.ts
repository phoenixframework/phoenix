// wraps value in closure or returns closure
export function closure<T>(value: T | (() => T)): () => T {
  if (typeof value === "function") {
    return value as () => T;
  } else {
    return () => value;
  }
}
