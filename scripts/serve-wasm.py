#!/usr/bin/env python3
"""Serve a QField wasm build with the COOP/COEP headers its threads require.

QGIS renders map layers in parallel, so the build has threads, so it needs
SharedArrayBuffer, so the browser demands those headers on every response.

--cloud forwards /api/ to a QFieldCloud instance so that the page and the API
answer on one origin. There is no other way to reach the API from a browser:
app.qfield.cloud sends no CORS headers, and nothing on this side can grant a
permission the server withholds. A deployment needs no proxy, it needs the page
served from the cloud host itself, which is a hosting decision, not a code one.
"""

import argparse
import http.server
import os
import sys
import urllib.error
import urllib.request

PORT = 8080
DEFAULT_CLOUD = "https://app.qfield.cloud"

HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "content-encoding",
    "content-length",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    cloud_url = None

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.is_cloud_path():
            self.forward("GET")
        else:
            super().do_GET()

    def do_HEAD(self):
        if self.is_cloud_path():
            self.forward("HEAD")
        else:
            super().do_HEAD()

    def do_POST(self):
        self.forward("POST")

    def do_PUT(self):
        self.forward("PUT")

    def do_PATCH(self):
        self.forward("PATCH")

    def do_DELETE(self):
        self.forward("DELETE")

    def is_cloud_path(self):
        return self.cloud_url and self.path.startswith("/api/")

    def forward(self, method):
        if not self.is_cloud_path():
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None

        request = urllib.request.Request(
            self.cloud_url + self.path, data=body, method=method
        )
        for header in ("Authorization", "Content-Type", "Accept"):
            if header in self.headers:
                request.add_header(header, self.headers[header])

        try:
            with urllib.request.urlopen(request) as response:
                self.relay(response.status, response.headers, response.read())
        except urllib.error.HTTPError as error:
            # A 401 means the API is working; do not turn it into a proxy error.
            self.relay(error.code, error.headers, error.read())
        except urllib.error.URLError as error:
            self.send_error(502, f"cannot reach {self.cloud_url}: {error.reason}")

    def relay(self, status, headers, body):
        self.send_response(status)
        for name, value in headers.items():
            if name.lower() not in HOP_BY_HOP:
                self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("directory", nargs="?", default=".")
    parser.add_argument("--cloud", nargs="?", const=DEFAULT_CLOUD, metavar="URL")
    arguments = parser.parse_args()

    if not os.path.isfile(os.path.join(arguments.directory, "qfield.html")):
        sys.exit(f"no qfield.html in {arguments.directory} — build it first")
    os.chdir(arguments.directory)

    if arguments.cloud:
        Handler.cloud_url = arguments.cloud.rstrip("/")

    print(f"http://localhost:{PORT}/qfield.html")
    print(
        f"http://localhost:{PORT}/qfield.html?project=<path in the virtual filesystem>"
    )
    if Handler.cloud_url:
        print()
        print(f"/api/ forwards to {Handler.cloud_url}")
        print("In QField, set the QFieldCloud server to:")
        print(f"    http://localhost:{PORT}")
    http.server.ThreadingHTTPServer(("localhost", PORT), Handler).serve_forever()
