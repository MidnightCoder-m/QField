// Boot a QField wasm build in headless Chrome and report what the page did.
//
//   node scripts/wasm-headless.js <url> [seconds]
//
// Needs a Chrome already listening on 9222; verify-wasm-build.sh starts one.
// Emscripten routes stdout/stderr through console.log, so QField's own output
// arrives here as consoleAPICalled events.
//
// ESCAPES=n sends n Escape keys (QField greets a first run with a tour), and
// CLICKS="x,y;x,y" clicks instead, for anything that must be dismissed without
// Escape's other meaning: at the top level it closes the project, then the app.

const CDP_PORT = 9222;
const url = process.argv[2];
const seconds = Number(process.argv[3] || 30);

if (!url) {
  console.error("usage: node wasm-headless.js <url> [seconds]");
  process.exit(2);
}

async function main() {
  const target = await fetch(
    `http://localhost:${CDP_PORT}/json/new?${encodeURIComponent(url)}`,
    { method: "PUT" },
  ).then((r) => r.json());

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  const messages = [];

  await new Promise((resolve) => (ws.onopen = resolve));

  let nextId = 1;
  const pending = new Map();
  const call = (method, params) =>
    new Promise((resolve) => {
      const id = nextId++;
      pending.set(id, resolve);
      ws.send(JSON.stringify({ id, method, params: params ?? {} }));
    });

  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);

    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message.result);
      pending.delete(message.id);
      return;
    }

    if (message.method === "Runtime.consoleAPICalled") {
      const text = message.params.args
        .map((argument) => argument.value ?? argument.description ?? "")
        .join(" ");
      messages.push(`[${message.params.type}] ${text}`);
    }

    if (message.method === "Runtime.exceptionThrown") {
      const details = message.params.exceptionDetails;
      messages.push(
        `[EXCEPTION] ${details.text} ${details.exception?.description ?? ""}`.trim(),
      );
    }

    if (message.method === "Log.entryAdded") {
      messages.push(
        `[log:${message.params.entry.level}] ${message.params.entry.text}`,
      );
    }
  };

  await call("Runtime.enable");
  await call("Log.enable");
  await call("Page.enable");
  await call("Page.navigate", { url });

  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));

  for (let i = 0; i < Number(process.env.ESCAPES || 0); i++) {
    for (const type of ["keyDown", "keyUp"]) {
      await call("Input.dispatchKeyEvent", {
        type,
        key: "Escape",
        code: "Escape",
        windowsVirtualKeyCode: 27,
        nativeVirtualKeyCode: 27,
      });
    }
    await new Promise((resolve) => setTimeout(resolve, 1500));
  }

  for (const point of (process.env.CLICKS || "").split(";").filter(Boolean)) {
    const [x, y] = point.split(",").map(Number);
    for (const type of ["mousePressed", "mouseReleased"]) {
      await call("Input.dispatchMouseEvent", {
        type,
        x,
        y,
        button: "left",
        clickCount: 1,
      });
    }
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }

  // A blank page has three very different causes — a container with no size, a
  // canvas that was never created, or a canvas that painted nothing — and they
  // look identical from the outside. Measure before concluding anything.
  const dom = await call("Runtime.evaluate", {
    returnByValue: true,
    expression: `(() => {
      const container = document.querySelector('#screen');

      // Qt builds its screen inside a shadow root, so a plain querySelectorAll
      // sees an empty container and tells you nothing.
      const walk = (root, out = []) => {
        for (const element of root.querySelectorAll('*')) {
          out.push(element);
          if (element.shadowRoot) walk(element.shadowRoot, out);
        }
        return out;
      };
      const canvases = walk(document)
        .filter(element => element.tagName === 'CANVAS')
        .map(canvas => ({
          attr: canvas.width + 'x' + canvas.height,
          css: Math.round(canvas.getBoundingClientRect().width) + 'x' +
               Math.round(canvas.getBoundingClientRect().height),
          ctx: (() => { try {
            return canvas.getContext('webgl2') ? 'webgl2' :
                   canvas.getContext('webgl') ? 'webgl' : 'none';
          } catch (error) { return 'throws: ' + error.message; } })(),
        }));
      return JSON.stringify({
        screenSize: container
          ? Math.round(container.getBoundingClientRect().width) + 'x' +
            Math.round(container.getBoundingClientRect().height)
          : 'missing',
        canvasCount: canvases.length,
        canvases,
      }, null, 1);
    })()`,
  });
  messages.push("[DOM] " + (dom.result?.value ?? "unavailable"));

  console.log("=== console ===");
  console.log(messages.length ? messages.join("\n") : "(nothing)");

  try {
    const shot = await call("Page.captureScreenshot", { format: "png" });
    const target = process.env.SCREENSHOT || "/tmp/qfield-wasm.png";
    const fs = await import("node:fs");
    fs.writeFileSync(target, Buffer.from(shot.data, "base64"));
    console.log(`\n=== screenshot === ${target}`);
  } catch {}

  ws.close();
  process.exit(0);
}

main().catch((error) => {
  console.error("harness failed:", error);
  process.exit(1);
});
