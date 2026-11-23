#!/usr/bin/env python3
"""
Reference Bring-Your-Own (BYO) backend for Onto the Radio.

Zero third-party dependencies (Python 3.10+ stdlib only). Scans a local audio
folder, joins optional canonical IDs (mbid:/isrc:) against Manifold's
k-anonymous `/api/v1/shard/:prefix` endpoint without leaking file paths or track
lists, imports signed Manifold radio lenses, and serves the exact HTTP API
expected by `Shared/HomeRadioClient.swift`.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from datetime import datetime, timezone
import hashlib
import hmac
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import secrets
import sys
import threading
from typing import Any
import urllib.error
import urllib.parse
import urllib.request

AUDIO_EXTENSIONS: dict[str, str] = {
    ".m4a": "audio/mp4",
    ".mp4": "audio/mp4",
    ".mp3": "audio/mpeg",
    ".flac": "audio/flac",
    ".wav": "audio/wav",
    ".aac": "audio/aac",
    ".ogg": "audio/ogg",
    ".opus": "audio/opus",
}

COVER_FILENAMES = (
    "cover.jpg",
    "cover.jpeg",
    "cover.png",
    "folder.jpg",
    "folder.png",
    "artwork.jpg",
    "artwork.png",
)

STATION_PALETTE = ("#2F6BFF", "#D97706", "#0D9488", "#DC2626", "#7C3AED", "#2563EB")


def shard_prefix(work_id: str) -> str:
    """Return the 2-hex-char k-anonymous bucket prefix matching Manifold."""
    return hashlib.sha256(work_id.encode("utf-8")).hexdigest()[:2]


def deterministic_color(seed: str) -> str:
    digest = hashlib.sha256(seed.encode("utf-8")).digest()
    return STATION_PALETTE[digest[0] % len(STATION_PALETTE)]


def cosine_similarity(a: list[float] | list[int], b: list[float] | list[int]) -> float:
    n = min(len(a), len(b))
    if n == 0:
        return 0.0
    dot = 0.0
    na = 0.0
    nb = 0.0
    for i in range(n):
        va = float(a[i])
        vb = float(b[i])
        dot += va * vb
        na += va * va
        nb += vb * vb
    denom = math.sqrt(na) * math.sqrt(nb)
    return dot / denom if denom > 0.0 else 0.0


def parse_filename_metadata(rel_path: Path) -> tuple[str, str]:
    stem = rel_path.stem.strip()
    if " - " in stem:
        artist, title = stem.split(" - ", 1)
        return artist.strip() or "Unknown Artist", title.strip() or stem
    parent = rel_path.parent.name.strip()
    if parent and parent != ".":
        return parent, stem or "Untitled"
    return "Local Library", stem or "Untitled"


def parse_byte_range(header_val: str | None, total_size: int) -> tuple[int, int] | None:
    """Parse an HTTP Range header for a single byte range; return None if unsatisfiable."""
    if not header_val:
        return None
    spec = header_val.strip()
    if not spec.startswith("bytes=") or "," in spec or total_size <= 0:
        return None
    range_part = spec[len("bytes=") :].strip()
    if "-" not in range_part:
        return None
    start_s, end_s = range_part.split("-", 1)
    try:
        if start_s == "":
            suffix = int(end_s)
            if suffix <= 0:
                return None
            start = max(0, total_size - suffix)
            end = total_size - 1
            return (start, end)
        start = int(start_s)
        if start < 0 or start >= total_size:
            return None
        if end_s == "":
            return (start, total_size - 1)
        end = min(total_size - 1, int(end_s))
        if end < start:
            return None
        return (start, end)
    except ValueError:
        return None


@dataclass
class TrackRecord:
    sha: str
    path: Path
    mime: str
    size: int
    artist: str
    title: str
    album: str
    year: int
    genre: str
    energy: float
    heaviness: float
    duration: float
    color: str
    art_path: Path | None
    art_mime: str | None
    work_id: str | None = None
    x: float | None = None
    y: float | None = None
    vec32: list[int] | None = None
    tag: str | None = None


@dataclass
class RadioBackendState:
    media_dir: Path
    password: str
    server_name: str
    manifold_hub: str | None
    offline: bool
    catalog_path: Path | None
    state_dir: Path
    tracks: dict[str, TrackRecord] = field(default_factory=dict)
    tracks_by_work_id: dict[str, TrackRecord] = field(default_factory=dict)
    manifold_works: dict[str, dict[str, Any]] = field(default_factory=dict)
    lenses: list[dict[str, Any]] = field(default_factory=list)
    sessions: set[str] = field(default_factory=set)
    pick_tokens: dict[str, str] = field(default_factory=dict)
    taste_scores: dict[str, float] = field(default_factory=dict)
    lock: threading.RLock = field(default_factory=threading.RLock)

    def load_events(self) -> None:
        events_file = self.state_dir / "events.jsonl"
        if not events_file.is_file():
            return
        with self.lock:
            for line in events_file.read_text(encoding="utf-8").splitlines():
                if not line.strip():
                    continue
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue
                sha = str(ev.get("s") or "")
                kind = str(ev.get("ev") or "")
                if sha in self.tracks:
                    self._apply_taste_delta_locked(sha, kind)

    def _apply_taste_delta_locked(self, sha: str, kind: str) -> None:
        cur = self.taste_scores.get(sha, 0.0)
        if kind == "like":
            self.taste_scores[sha] = cur + 0.35
        elif kind == "finish":
            self.taste_scores[sha] = cur + 0.15
        elif kind == "dislike":
            # Exceed maximum anchor cosine (1.0) so an explicitly disliked track yields to any valid alternative.
            self.taste_scores[sha] = cur - 1.25

    def scan_media(self) -> None:
        catalog: dict[str, dict[str, Any]] = {}
        if self.catalog_path and self.catalog_path.is_file():
            raw = json.loads(self.catalog_path.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                catalog = {str(k): v for k, v in raw.items() if isinstance(v, dict)}

        scanned: dict[str, TrackRecord] = {}
        by_wid: dict[str, TrackRecord] = {}

        if not self.media_dir.is_dir():
            raise FileNotFoundError(f"Media directory does not exist: {self.media_dir}")

        for file_path in sorted(self.media_dir.rglob("*")):
            if not file_path.is_file():
                continue
            ext = file_path.suffix.lower()
            if ext not in AUDIO_EXTENSIONS:
                continue

            rel_posix = file_path.relative_to(self.media_dir).as_posix()
            sha = hashlib.sha256(rel_posix.encode("utf-8")).hexdigest()[:16]
            default_artist, default_title = parse_filename_metadata(Path(rel_posix))
            meta = catalog.get(rel_posix, {})

            art_path: Path | None = None
            art_mime: str | None = None
            for cover_name in COVER_FILENAMES:
                candidate = file_path.parent / cover_name
                if candidate.is_file():
                    art_path = candidate
                    art_mime = "image/png" if candidate.suffix.lower() == ".png" else "image/jpeg"
                    break

            work_id = meta.get("workId")
            work_id_str = str(work_id).strip() if isinstance(work_id, str) and work_id.strip() else None
            artist = str(meta.get("artist") or default_artist)
            title = str(meta.get("title") or default_title)
            genre = str(meta.get("genre") or "local mix")
            year = int(meta.get("year") or 2024)
            energy = float(meta.get("energy") if meta.get("energy") is not None else 0.45)
            heaviness = float(meta.get("heaviness") if meta.get("heaviness") is not None else 0.35)
            duration = float(meta.get("duration") if meta.get("duration") is not None else 210.0)
            vec32 = meta.get("vec32") if isinstance(meta.get("vec32"), list) else None

            rec = TrackRecord(
                sha=sha,
                path=file_path,
                mime=AUDIO_EXTENSIONS[ext],
                size=file_path.stat().st_size,
                artist=artist,
                title=title,
                album=str(meta.get("album") or rel_posix.split("/")[0] if "/" in rel_posix else "Library"),
                year=year,
                genre=genre,
                energy=max(0.0, min(1.0, energy)),
                heaviness=max(0.0, min(1.0, heaviness)),
                duration=duration,
                color=str(meta.get("color") or deterministic_color(artist or title)),
                art_path=art_path,
                art_mime=art_mime,
                work_id=work_id_str,
                x=float(meta["x"]) if meta.get("x") is not None else None,
                y=float(meta["y"]) if meta.get("y") is not None else None,
                vec32=[int(v) for v in vec32] if vec32 else None,
                tag=str(meta["tag"]) if meta.get("tag") else None,
            )
            scanned[sha] = rec
            if work_id_str:
                by_wid[work_id_str] = rec

        with self.lock:
            self.tracks = scanned
            self.tracks_by_work_id = by_wid

    def sync_manifold(self) -> None:
        """Fetch signed lenses and k-anonymous 2-hex-char shards without exposing local paths."""
        if self.offline or not self.manifold_hub:
            return
        hub = self.manifold_hub.rstrip("/")

        try:
            req = urllib.request.Request(f"{hub}/api/v1/lenses?domain=radio", headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=8) as resp:
                lenses_env = json.loads(resp.read().decode("utf-8"))
            fetched_lenses = [l for l in lenses_env.get("lenses", []) if isinstance(l, dict)]
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
            return

        prefixes: set[str] = set()
        with self.lock:
            for rec in self.tracks.values():
                if rec.work_id:
                    prefixes.add(shard_prefix(rec.work_id))
        for lens in fetched_lenses:
            for anc in lens.get("anchors") or []:
                wid = anc.get("workId") if isinstance(anc, dict) else None
                if isinstance(wid, str) and wid:
                    prefixes.add(shard_prefix(wid))

        joined_works: dict[str, dict[str, Any]] = {}
        for prefix in sorted(prefixes):
            try:
                shard_url = f"{hub}/api/v1/shard/{urllib.parse.quote(prefix)}?domain=radio"
                req = urllib.request.Request(shard_url, headers={"Accept": "application/json"})
                with urllib.request.urlopen(req, timeout=8) as resp:
                    shard_env = json.loads(resp.read().decode("utf-8"))
                for w in shard_env.get("works", []):
                    if isinstance(w, dict) and isinstance(w.get("workId"), str):
                        joined_works[w["workId"]] = w
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
                continue

        with self.lock:
            self.lenses = fetched_lenses
            self.manifold_works = joined_works
            for rec in self.tracks.values():
                if not rec.work_id:
                    continue
                mw = joined_works.get(rec.work_id)
                if not mw:
                    continue
                if mw.get("x") is not None:
                    rec.x = float(mw["x"])
                if mw.get("y") is not None:
                    rec.y = float(mw["y"])
                if isinstance(mw.get("vec32"), list) and mw["vec32"]:
                    rec.vec32 = [int(v) for v in mw["vec32"]]
                if mw.get("energy") is not None:
                    rec.energy = float(mw["energy"])
                if mw.get("heaviness") is not None:
                    rec.heaviness = float(mw["heaviness"])
                if mw.get("hook") and not rec.tag:
                    rec.tag = str(mw["hook"])

    def build_home_payload(self) -> dict[str, Any]:
        with self.lock:
            song_tiles: list[dict[str, Any]] = []
            for rec in list(self.tracks.values())[:24]:
                tile: dict[str, Any] = {
                    "kind": "song",
                    "s": rec.sha,
                    "title": rec.title,
                    "sub": f"{rec.artist} · {rec.year}",
                    "artist": rec.artist,
                    "art": rec.art_path is not None,
                    "color": rec.color,
                }
                if rec.x is not None and rec.y is not None:
                    tile["point"] = {"x": rec.x, "y": rec.y}
                song_tiles.append(tile)

            station_tiles: list[dict[str, Any]] = []
            for lens in self.lenses:
                lens_id = str(lens.get("id") or "")
                name = str(lens.get("name") or lens_id)
                summary = str(lens.get("summary") or "Manifold signed station")
                color = deterministic_color(lens_id or name)
                station_tiles.append(
                    {
                        "kind": "station",
                        "title": name,
                        "sub": summary,
                        "color": color,
                        "station": {
                            "id": lens_id,
                            "name": name,
                            "color": color,
                            "count": len(self.tracks),
                        },
                    }
                )

            station_tiles.append(
                {
                    "kind": "station",
                    "title": "All Library",
                    "sub": f"{len(self.tracks)} local tracks ordered by taste",
                    "color": "#0D9488",
                    "station": {
                        "id": "all",
                        "name": "All Library",
                        "color": "#0D9488",
                        "count": len(self.tracks),
                    },
                }
            )

            return {
                "shelves": [
                    {"id": "library", "title": "Your Library", "tiles": song_tiles},
                    {"id": "stations", "title": "Stations", "tiles": station_tiles},
                ]
            }

    def build_queue_payload(self, mood: str, n: int) -> dict[str, Any]:
        clean_mood = mood.strip()
        if clean_mood.startswith("station:"):
            clean_mood = clean_mood[len("station:") :]

        with self.lock:
            lens = next((l for l in self.lenses if l.get("id") == clean_mood), None)
            anchors: list[tuple[list[int], float, str]] = []
            if lens:
                for anc in lens.get("anchors") or []:
                    if not isinstance(anc, dict):
                        continue
                    wid = str(anc.get("workId") or "")
                    wt = float(anc.get("weight") or 1.0)
                    mw = self.manifold_works.get(wid)
                    vec = mw.get("vec32") if isinstance(mw, dict) else None
                    anchors.append((vec if isinstance(vec, list) else [], wt, wid))

            scored: list[tuple[float, TrackRecord]] = []
            for rec in self.tracks.values():
                base = 0.65
                if anchors and rec.vec32:
                    total = 0.0
                    weights = 0.0
                    best = 0.0
                    for avec, wt, wid in anchors:
                        if rec.work_id == wid:
                            sim = 1.0
                        elif avec:
                            sim = max(0.0, cosine_similarity(avec, rec.vec32))
                        else:
                            sim = 0.0
                        total += sim * wt
                        weights += wt
                        best = max(best, sim)
                    if weights > 0.0:
                        base = (total / weights) * 0.7 + best * 0.3
                elif clean_mood and clean_mood.lower() != "all":
                    hay = f"{rec.genre} {rec.tag or ''} {rec.title} {rec.artist}".lower()
                    if clean_mood.lower() in hay:
                        base = 0.85

                taste = self.taste_scores.get(rec.sha, 0.0)
                scored.append((base + taste, rec))

            scored.sort(key=lambda pair: (-pair[0], pair[1].artist.lower(), pair[1].title.lower()))
            limit = max(1, min(100, n))
            picks: list[dict[str, Any]] = []
            for _, rec in scored[:limit]:
                token = secrets.token_urlsafe(12)
                self.pick_tokens[token] = rec.sha
                if len(self.pick_tokens) > 4096:
                    oldest = next(iter(self.pick_tokens))
                    self.pick_tokens.pop(oldest, None)

                pick: dict[str, Any] = {
                    "s": rec.sha,
                    "a": rec.artist,
                    "t": rec.title,
                    "al": rec.album,
                    "y": rec.year,
                    "g": rec.genre,
                    "e": round(rec.energy, 3),
                    "h": round(rec.heaviness, 3),
                    "tag": rec.tag or rec.genre,
                    "dur": round(rec.duration, 1),
                    "color": rec.color,
                    "art": rec.art_path is not None,
                    "pt": token,
                }
                if rec.x is not None:
                    pick["x"] = rec.x
                if rec.y is not None:
                    pick["yy"] = rec.y
                picks.append(pick)

            return {"picks": picks}

    def record_event(self, pick_token: str, event: str, pos: float) -> bool:
        with self.lock:
            sha = self.pick_tokens.get(pick_token)
            if not sha or sha not in self.tracks:
                return False
            self._apply_taste_delta_locked(sha, event)
            self.state_dir.mkdir(parents=True, exist_ok=True)
            entry = {
                "ts": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                "s": sha,
                "ev": event,
                "pos": round(float(pos), 2),
            }
            with (self.state_dir / "events.jsonl").open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(entry) + "\n")
            return True


def make_handler(backend: RadioBackendState) -> type[BaseHTTPRequestHandler]:
    class RadioRequestHandler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, format: str, *args: Any) -> None:
            return

        def _read_json_body(self) -> dict[str, Any] | None:
            try:
                length = int(self.headers.get("Content-Length") or "0")
            except ValueError:
                return None
            if length <= 0 or length > 1_048_576:
                return {}
            raw = self.rfile.read(length)
            try:
                parsed = json.loads(raw.decode("utf-8"))
                return parsed if isinstance(parsed, dict) else None
            except (UnicodeDecodeError, json.JSONDecodeError):
                return None

        def _send_json(
            self,
            status: int,
            payload: dict[str, Any],
            extra_headers: list[tuple[str, str]] | None = None,
        ) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            if extra_headers:
                for k, v in extra_headers:
                    self.send_header(k, v)
            self.end_headers()
            self.wfile.write(body)

        def _is_authenticated(self) -> bool:
            cookie_header = self.headers.get("Cookie")
            if not cookie_header:
                return False
            jar = cookies.SimpleCookie()
            try:
                jar.load(cookie_header)
            except cookies.CookieError:
                return False
            morsel = jar.get("otr_session")
            if not morsel:
                return False
            with backend.lock:
                return morsel.value in backend.sessions

        def _require_auth(self) -> bool:
            if not self._is_authenticated():
                self._send_json(401, {"error": "unauthorized"})
                return False
            return True

        def _serve_audio(self, sha: str, head_only: bool) -> None:
            if not self._require_auth():
                return
            with backend.lock:
                rec = backend.tracks.get(sha)
            if not rec or not rec.path.is_file():
                self._send_json(404, {"error": "not_found"})
                return

            file_size = rec.path.stat().st_size
            range_hdr = self.headers.get("Range")
            if range_hdr:
                byte_range = parse_byte_range(range_hdr, file_size)
                if byte_range is None:
                    self.send_response(416)
                    self.send_header("Content-Range", f"bytes */{file_size}")
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                start, end = byte_range
                chunk_len = end - start + 1
                self.send_response(206)
                self.send_header("Content-Type", rec.mime)
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
                self.send_header("Content-Length", str(chunk_len))
                self.end_headers()
                if head_only:
                    return
                with rec.path.open("rb") as fh:
                    fh.seek(start)
                    remaining = chunk_len
                    while remaining > 0:
                        buf = fh.read(min(65536, remaining))
                        if not buf:
                            break
                        self.wfile.write(buf)
                        remaining -= len(buf)
                return

            self.send_response(200)
            self.send_header("Content-Type", rec.mime)
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Length", str(file_size))
            self.end_headers()
            if head_only:
                return
            with rec.path.open("rb") as fh:
                while True:
                    buf = fh.read(65536)
                    if not buf:
                        break
                    self.wfile.write(buf)

        def do_HEAD(self) -> None:
            path = urllib.parse.urlsplit(self.path).path
            if path.startswith("/api/audio/"):
                sha = path[len("/api/audio/") :]
                self._serve_audio(sha, head_only=True)
                return
            self._send_json(404, {"error": "not_found"})

        def do_GET(self) -> None:
            path = urllib.parse.urlsplit(self.path).path
            if path == "/api/home":
                if not self._require_auth():
                    return
                self._send_json(200, backend.build_home_payload())
                return

            if path.startswith("/api/audio/"):
                sha = path[len("/api/audio/") :]
                self._serve_audio(sha, head_only=False)
                return

            if path.startswith("/api/art/"):
                if not self._require_auth():
                    return
                sha = path[len("/api/art/") :]
                with backend.lock:
                    rec = backend.tracks.get(sha)
                if not rec or not rec.art_path or not rec.art_path.is_file():
                    self._send_json(404, {"error": "art_not_found"})
                    return
                data = rec.art_path.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", rec.art_mime or "image/jpeg")
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "private, max-age=3600")
                self.end_headers()
                self.wfile.write(data)
                return

            self._send_json(404, {"error": "not_found"})

        def do_POST(self) -> None:
            path = urllib.parse.urlsplit(self.path).path
            if path == "/api/login":
                body = self._read_json_body()
                if body is None:
                    self._send_json(400, {"error": "invalid_json"})
                    return
                supplied = str(body.get("pass") or "")
                if not supplied or not hmac.compare_digest(supplied, backend.password):
                    self._send_json(401, {"error": "unauthorized"})
                    return
                session_id = secrets.token_urlsafe(32)
                with backend.lock:
                    backend.sessions.add(session_id)
                self._send_json(
                    200,
                    {"name": backend.server_name},
                    extra_headers=[
                        ("Set-Cookie", f"otr_session={session_id}; Path=/; HttpOnly; SameSite=Lax")
                    ],
                )
                return

            if not self._require_auth():
                return

            body = self._read_json_body()
            if body is None:
                self._send_json(400, {"error": "invalid_json"})
                return

            if path == "/api/queue":
                mood = str(body.get("mood") or "all")
                try:
                    n = int(body.get("n") or 18)
                except (TypeError, ValueError):
                    n = 18
                self._send_json(200, backend.build_queue_payload(mood=mood, n=n))
                return

            if path == "/api/event":
                pt = str(body.get("pt") or "")
                ev = str(body.get("ev") or "")
                try:
                    pos = float(body.get("pos") or 0.0)
                except (TypeError, ValueError):
                    pos = 0.0
                if not pt or not ev:
                    self._send_json(400, {"error": "missing_fields"})
                    return
                ok = backend.record_event(pick_token=pt, event=ev, pos=pos)
                self._send_json(200 if ok else 404, {"ok": ok})
                return

            self._send_json(404, {"error": "not_found"})

    return RadioRequestHandler


def create_server(
    *,
    media_dir: Path,
    password: str,
    host: str = "127.0.0.1",
    port: int = 8787,
    name: str = "My Radio Server",
    manifold_hub: str | None = "https://manifold-chi.vercel.app",
    offline: bool = False,
    catalog_path: Path | None = None,
    state_dir: Path | None = None,
) -> tuple[ThreadingHTTPServer, RadioBackendState]:
    resolved_state = state_dir or (Path.home() / ".local" / "state" / "onto-the-radio-byo")
    backend = RadioBackendState(
        media_dir=media_dir.expanduser().resolve(),
        password=password,
        server_name=name,
        manifold_hub=manifold_hub,
        offline=offline,
        catalog_path=catalog_path.expanduser().resolve() if catalog_path else None,
        state_dir=resolved_state.expanduser().resolve(),
    )
    backend.scan_media()
    backend.load_events()
    backend.sync_manifold()
    httpd = ThreadingHTTPServer((host, port), make_handler(backend))
    return httpd, backend


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Reference BYO backend for Onto the Radio")
    parser.add_argument("--media-dir", required=True, help="Directory of your local audio files")
    parser.add_argument("--pass", dest="password", default=os.environ.get("RADIO_PASS", ""), help="Login password (or env RADIO_PASS)")
    parser.add_argument("--host", default="127.0.0.1", help="Bind address (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8787, help="Bind port (default: 8787)")
    parser.add_argument("--name", default="My Radio Server", help="Display name returned after sign-in")
    parser.add_argument("--manifold-hub", default="https://manifold-chi.vercel.app", help="Manifold hub base URL")
    parser.add_argument("--offline", action="store_true", help="Skip fetching lenses/shards from Manifold")
    parser.add_argument("--catalog", type=Path, default=None, help="Optional JSON mapping relative path -> {workId, artist, title, ...}")
    parser.add_argument("--state-dir", type=Path, default=Path.home() / ".local" / "state" / "onto-the-radio-byo", help="Directory for events.jsonl")
    args = parser.parse_args(argv)

    if not args.password:
        print("Error: --pass or RADIO_PASS must be non-empty.", file=sys.stderr)
        return 2

    httpd, backend = create_server(
        media_dir=Path(args.media_dir),
        password=args.password,
        host=args.host,
        port=args.port,
        name=args.name,
        manifold_hub=args.manifold_hub,
        offline=args.offline,
        catalog_path=args.catalog,
        state_dir=args.state_dir,
    )
    addr, bound_port = httpd.server_address[:2]
    print(
        f"Onto the Radio BYO backend listening on http://{addr}:{bound_port} "
        f"({len(backend.tracks)} tracks, {len(backend.lenses)} Manifold lenses)"
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
