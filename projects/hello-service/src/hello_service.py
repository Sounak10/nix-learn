#!/usr/bin/env python3
"""A dependency-free HTTP service and client."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


def response_document(greeting: str) -> dict[str, str]:
    return {"message": greeting, "service": "hello-service"}


def make_handler(greeting: str) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path == "/healthz":
                self._send(200, {"status": "ok"})
            elif self.path == "/":
                self._send(200, response_document(greeting))
            else:
                self._send(404, {"error": "not found"})

        def _send(self, status: int, document: dict[str, str]) -> None:
            payload = json.dumps(document, sort_keys=True).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, message: str, *args: Any) -> None:
            print(f"{self.address_string()} - {message % args}", file=sys.stderr)

    return Handler


def serve(address: str, port: int, greeting: str) -> None:
    server = ThreadingHTTPServer((address, port), make_handler(greeting))
    print(f"listening on http://{address}:{server.server_port}", flush=True)
    server.serve_forever()


def config_path() -> Path:
    config_home = os.environ.get("XDG_CONFIG_HOME")
    base = Path(config_home) if config_home else Path.home() / ".config"
    return base / "hello-service" / "config.json"


def load_client_endpoint() -> str:
    path = config_path()
    if not path.exists():
        return "http://127.0.0.1:8080"
    document = json.loads(path.read_text(encoding="utf-8"))
    endpoint = document.get("endpoint")
    if not isinstance(endpoint, str) or not endpoint.startswith(("http://", "https://")):
        raise ValueError(f"{path} must contain an HTTP(S) endpoint")
    return endpoint.rstrip("/")


def client(endpoint: str, health: bool) -> int:
    url = endpoint.rstrip("/") + ("/healthz" if health else "/")
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            print(response.read().decode())
        return 0
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"hello-client: {error}", file=sys.stderr)
        return 1


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="hello-service")
    subcommands = result.add_subparsers(dest="command", required=True)

    server = subcommands.add_parser("serve", help="run the HTTP server")
    server.add_argument("--address", default=os.environ.get("HELLO_ADDRESS", "127.0.0.1"))
    server.add_argument("--port", type=int, default=int(os.environ.get("HELLO_PORT", "8080")))
    server.add_argument("--greeting", default=os.environ.get("HELLO_GREETING", "Hello from Nix!"))

    request = subcommands.add_parser("client", help="query a running server")
    request.add_argument("--endpoint", default=None)
    request.add_argument("--health", action="store_true")
    return result


def main() -> int:
    arguments = parser().parse_args()
    if arguments.command == "serve":
        serve(arguments.address, arguments.port, arguments.greeting)
        return 0
    return client(arguments.endpoint or load_client_endpoint(), arguments.health)


if __name__ == "__main__":
    raise SystemExit(main())
