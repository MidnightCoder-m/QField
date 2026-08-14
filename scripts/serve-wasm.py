#!/usr/bin/env python3
"""Serve a QField wasm build with the headers its threads require.

QGIS renders map layers in parallel, so the build has threads, so it needs
SharedArrayBuffer, so the browser demands COOP/COEP on every response. Served
without them the page loads and then stops with a message about
SharedArrayBuffer that says nothing about the cause.

The same headers make the browser refuse any cross-origin resource that does
not opt in with Cross-Origin-Resource-Policy — which is why some tile servers
work in the browser build and others do not.

    ./scripts/serve-wasm.py [directory]

Any real deployment needs the same two headers on every response.
"""

import http.server
import os
import sys

PORT = 8080
ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    if not os.path.isfile(os.path.join(ROOT, "qfield.html")):
        sys.exit(f"no qfield.html in {ROOT} — build it first")
    os.chdir(ROOT)
    print(f"http://localhost:{PORT}/qfield.html")
    print(
        f"http://localhost:{PORT}/qfield.html?project=<path in the virtual filesystem>"
    )
    http.server.ThreadingHTTPServer(("localhost", PORT), Handler).serve_forever()
