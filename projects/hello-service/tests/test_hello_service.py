import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

from hello_service import config_path, load_client_endpoint, make_handler, response_document
from http.server import ThreadingHTTPServer


class HelloServiceTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler("Test greeting"))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, path):
        url = f"http://127.0.0.1:{self.server.server_port}{path}"
        with urllib.request.urlopen(url, timeout=2) as response:
            return response.status, json.loads(response.read())

    def test_response_document(self):
        self.assertEqual(
            response_document("hello"),
            {"message": "hello", "service": "hello-service"},
        )

    def test_root_and_health_endpoints(self):
        self.assertEqual(self.request("/"), (200, {"message": "Test greeting", "service": "hello-service"}))
        self.assertEqual(self.request("/healthz"), (200, {"status": "ok"}))

    def test_unknown_endpoint_is_404(self):
        with self.assertRaises(urllib.error.HTTPError) as raised:
            self.request("/missing")
        self.assertEqual(raised.exception.code, 404)
        raised.exception.close()

    def test_client_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "hello-service" / "config.json"
            path.parent.mkdir()
            path.write_text('{"endpoint":"https://service.example/"}', encoding="utf-8")
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}):
                self.assertEqual(config_path(), path)
                self.assertEqual(load_client_endpoint(), "https://service.example")


if __name__ == "__main__":
    unittest.main()
