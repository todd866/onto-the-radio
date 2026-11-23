#!/usr/bin/env python3
"""End-to-end tests for the Onto the Radio reference BYO backend."""

from __future__ import annotations

import hashlib
from http.cookiejar import CookieJar
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

from server import create_server, shard_prefix  # noqa: E402


class BYOBackendTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.media_dir = self.root / "media"
        album_a = self.media_dir / "Artist Alpha"
        album_b = self.media_dir / "Artist Beta"
        album_a.mkdir(parents=True)
        album_b.mkdir(parents=True)

        self.audio_a_bytes = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        self.audio_b_bytes = b"abcdefghijklmnopqrstuvwxyz0123456789"
        (album_a / "Artist Alpha - First Signal.m4a").write_bytes(self.audio_a_bytes)
        (album_b / "Artist Beta - Quiet Harbor.mp3").write_bytes(self.audio_b_bytes)
        self.art_bytes = b"\x89PNG\r\n\x1a\nFAKEPNG"
        (album_a / "cover.png").write_bytes(self.art_bytes)

        self.work_id_a = "mbid:11111111-1111-4111-8111-111111111111"
        self.work_id_b = "mbid:22222222-2222-4222-8222-222222222222"
        catalog = {
            "Artist Alpha/Artist Alpha - First Signal.m4a": {
                "workId": self.work_id_a,
                "artist": "Artist Alpha",
                "title": "First Signal",
                "year": 2021,
                "genre": "ambient",
            },
            "Artist Beta/Artist Beta - Quiet Harbor.mp3": {
                "workId": self.work_id_b,
                "artist": "Artist Beta",
                "title": "Quiet Harbor",
                "year": 2023,
                "genre": "jazz",
            },
        }
        self.catalog_path = self.root / "catalog.json"
        self.catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
        self.state_dir = self.root / "state"

        # Mock Manifold hub verifying k-anonymous requests only.
        self.hub_requests: list[str] = []
        hub_requests = self.hub_requests
        wid_a = self.work_id_a
        wid_b = self.work_id_b
        pref_a = shard_prefix(wid_a)
        pref_b = shard_prefix(wid_b)

        lenses_payload = {
            "count": 1,
            "lenses": [
                {
                    "id": "lens:radio:night-signal",
                    "domain": "radio",
                    "name": "Night Signal",
                    "summary": "Synthetic test station anchored to First Signal",
                    "anchors": [{"workId": wid_a, "weight": 1.0, "mark": "good"}],
                }
            ],
        }
        works_by_prefix = {
            pref_a: [
                {
                    "workId": wid_a,
                    "domain": "radio",
                    "x": 0.42,
                    "y": -0.18,
                    "vec32": [10, 0, 0, 0],
                    "energy": 0.61,
                    "heaviness": 0.25,
                    "hook": "Pulsing signal",
                }
            ],
            pref_b: [
                {
                    "workId": wid_b,
                    "domain": "radio",
                    "x": -0.71,
                    "y": 0.33,
                    "vec32": [0, 10, 0, 0],
                    "energy": 0.24,
                    "heaviness": 0.14,
                    "hook": "Muted harbor brass",
                }
            ],
        }

        class MockManifoldHandler(BaseHTTPRequestHandler):
            def log_message(self, format: str, *args: object) -> None:
                return

            def do_GET(self) -> None:
                hub_requests.append(self.path)
                if self.path.startswith("/api/v1/lenses"):
                    body = json.dumps(lenses_payload).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    return
                if self.path.startswith("/api/v1/shard/"):
                    pref = self.path.split("/api/v1/shard/", 1)[1].split("?", 1)[0]
                    matches = works_by_prefix.get(pref, [])
                    body = json.dumps({"prefix": pref, "count": len(matches), "works": matches}).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    return
                self.send_response(404)
                self.end_headers()

        self.mock_hub = ThreadingHTTPServer(("127.0.0.1", 0), MockManifoldHandler)
        self.hub_thread = threading.Thread(target=self.mock_hub.serve_forever, daemon=True)
        self.hub_thread.start()
        hub_port = self.mock_hub.server_address[1]

        self.httpd, self.backend = create_server(
            media_dir=self.media_dir,
            password="test-pass-phrase",
            host="127.0.0.1",
            port=0,
            name="Test Radio Box",
            manifold_hub=f"http://127.0.0.1:{hub_port}",
            offline=False,
            catalog_path=self.catalog_path,
            state_dir=self.state_dir,
        )
        self.server_thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.server_thread.start()
        self.base_url = f"http://127.0.0.1:{self.httpd.server_address[1]}"

    def tearDown(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()
        self.mock_hub.shutdown()
        self.mock_hub.server_close()
        self.tmp.cleanup()

    def _new_opener(self) -> urllib.request.OpenerDirector:
        return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(CookieJar()))

    def test_auth_home_shard_join_media_and_events(self) -> None:
        anon = self._new_opener()
        for path in ("/api/home", "/api/audio/deadbeef"):
            with self.assertRaises(urllib.error.HTTPError) as ctx:
                anon.open(f"{self.base_url}{path}")
            self.assertEqual(ctx.exception.code, 401)
            ctx.exception.close()

        # Wrong password returns 401
        bad_req = urllib.request.Request(
            f"{self.base_url}/api/login",
            data=json.dumps({"pass": "wrong", "name": "Onto the Radio"}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            anon.open(bad_req)
        self.assertEqual(ctx.exception.code, 401)
        ctx.exception.close()

        # Verify k-anonymous Manifold calls never leaked paths/filenames
        self.assertTrue(any(p.startswith("/api/v1/lenses") for p in self.hub_requests))
        shard_calls = [p for p in self.hub_requests if p.startswith("/api/v1/shard/")]
        self.assertGreaterEqual(len(shard_calls), 2)
        for call in shard_calls:
            self.assertNotIn("Artist", call)
            self.assertNotIn(".m4a", call)
            self.assertNotIn(".mp3", call)

        # Sign in cleanly
        client = self._new_opener()
        login_req = urllib.request.Request(
            f"{self.base_url}/api/login",
            data=json.dumps({"pass": "test-pass-phrase", "name": "Onto the Radio"}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with client.open(login_req) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(json.loads(resp.read().decode("utf-8"))["name"], "Test Radio Box")

        # Validate GET /api/home schema expected by Swift HomeEnvelope
        with client.open(f"{self.base_url}/api/home") as resp:
            self.assertEqual(resp.status, 200)
            home = json.loads(resp.read().decode("utf-8"))

        shelves = home["shelves"]
        self.assertEqual(len(shelves), 2)
        songs = shelves[0]["tiles"]
        stations = shelves[1]["tiles"]
        self.assertEqual(len(songs), 2)
        for t in songs:
            self.assertEqual(t["kind"], "song")
            self.assertIsInstance(t["title"], str)
            self.assertIsInstance(t["sub"], str)
            self.assertIn("point", t)

        self.assertTrue(any(st["station"]["id"] == "lens:radio:night-signal" for st in stations))
        for st in stations:
            self.assertEqual(st["kind"], "station")
            self.assertIsInstance(st["title"], str)
            self.assertIsInstance(st["sub"], str)
            self.assertIsInstance(st["station"]["id"], str)
            self.assertIsInstance(st["station"]["name"], str)

        # Query station queue using the exact Swift prefix "station:<id>"
        q_req = urllib.request.Request(
            f"{self.base_url}/api/queue",
            data=json.dumps({"mood": "station:lens:radio:night-signal", "n": 18}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with client.open(q_req) as resp:
            self.assertEqual(resp.status, 200)
            picks = json.loads(resp.read().decode("utf-8"))["picks"]

        self.assertEqual(len(picks), 2)
        self.assertEqual(picks[0]["t"], "First Signal")
        self.assertAlmostEqual(picks[0]["x"], 0.42, places=2)
        sha_first = picks[0]["s"]
        pt_first = picks[0]["pt"]

        # Full GET /api/audio/<sha>?q=aac and HTTP 206 byte range request
        with client.open(f"{self.base_url}/api/audio/{sha_first}?q=aac") as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers.get("Accept-Ranges"), "bytes")
            self.assertEqual(resp.read(), self.audio_a_bytes)

        range_req = urllib.request.Request(
            f"{self.base_url}/api/audio/{sha_first}?q=aac",
            headers={"Range": "bytes=2-9"},
        )
        with client.open(range_req) as resp:
            self.assertEqual(resp.status, 206)
            self.assertEqual(resp.headers.get("Content-Range"), f"bytes 2-9/{len(self.audio_a_bytes)}")
            self.assertEqual(resp.read(), self.audio_a_bytes[2:10])

        # Sidecar art 200 on track with cover.png, 404 on track without art and unknown IDs
        with client.open(f"{self.base_url}/api/art/{sha_first}?size=300") as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.read(), self.art_bytes)

        sha_second = picks[1]["s"]
        for missing_path in (f"/api/art/{sha_second}?size=300", "/api/audio/..%2Fetc%2Fpasswd"):
            with self.assertRaises(urllib.error.HTTPError) as ctx:
                client.open(f"{self.base_url}{missing_path}")
            self.assertEqual(ctx.exception.code, 404)
            ctx.exception.close()

        # Dislike First Signal -> persists to events.jsonl and swaps order in next /api/queue
        ev_req = urllib.request.Request(
            f"{self.base_url}/api/event",
            data=json.dumps({"pt": pt_first, "ev": "dislike", "pos": 14.2}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with client.open(ev_req) as resp:
            self.assertEqual(resp.status, 200)
            self.assertTrue(json.loads(resp.read().decode("utf-8"))["ok"])

        events_log = (self.state_dir / "events.jsonl").read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(events_log), 1)
        self.assertEqual(json.loads(events_log[0])["ev"], "dislike")

        with client.open(q_req) as resp:
            re_ranked = json.loads(resp.read().decode("utf-8"))["picks"]
        self.assertEqual(re_ranked[0]["t"], "Quiet Harbor")


if __name__ == "__main__":
    unittest.main()
