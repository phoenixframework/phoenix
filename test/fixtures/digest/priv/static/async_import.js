async function asyncImport() {
  const app = await import("./app.js");
  console.log(app);
}

async function defaultAsyncImport() {
  const app = (await import("./app.js")).default;
  console.log(app);
}

function promiseImport() {
  import("./app.js").then((app) => {
    console.log(app);
  });
}

async function noDigestImport() {
  const thing = await import("https://example.com/thing.js");
  console.log(thing);
}

async function notAPathAsyncImport() {
  const notAsyncPath = {};
  await import(notAsyncPath);
}

async function notAPathPromiseImport() {
  const notPromisePath = {};
  import(notPromisePath).then(function (thing) {
    console.log(thing);
  });
}
