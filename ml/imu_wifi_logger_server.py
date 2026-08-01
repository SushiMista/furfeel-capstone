#!/usr/bin/env python3
"""Receives IMU batches over WiFi from imu_logger.ino and tags them with a
posture label you set from a small web page this same server hosts -- typing
directly into the terminal proved unreliable on some setups (background
stdin thread hit EOFError). The ESP32 runs off a power bank and posts over
WiFi, so the dog can move freely near this machine instead of next to a cable.

Usage:
    python ml/imu_wifi_logger_server.py --dog Charlotte --size small
    (then put this machine's IP -- check with `ipconfig` -- into the sketch's
    SERVER_URL, matching the --port below, default 8765)

While it runs: open http://localhost:<port>/ in a browser and click a
posture button (or type a custom one) any time the dog's activity changes.
Every row received after that is tagged with that label until you change it
again. Ctrl+C to stop.
"""
import argparse
import csv
import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import unquote

state = {"label": "unlabeled"}

PAGE = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>FurFeel Posture Logger</title>
<style>
body { font-family: system-ui, sans-serif; max-width: 480px; margin: 40px auto; padding: 0 16px; }
h1 { font-size: 20px; }
#label { font-size: 28px; font-weight: bold; padding: 14px; background: #eef2ff; border-radius: 8px; text-align: center; margin: 16px 0; }
#rows { color: #666; margin-bottom: 16px; }
.postures button { font-size: 16px; padding: 12px 16px; margin: 4px; border-radius: 8px; border: 1px solid #ccc; background: #fff; cursor: pointer; }
.postures button:hover { background: #eef2ff; }
.custom { margin-top: 20px; }
.custom input { font-size: 16px; padding: 10px; width: 55%; }
.custom button { font-size: 16px; padding: 10px 16px; }
</style>
</head>
<body>
<h1>FurFeel &mdash; Posture Data Logger</h1>
<div>Dog: <b>__DOG__</b> (__SIZE__)</div>
<div id="label">loading...</div>
<div id="rows"></div>
<div class="postures">
  <button onclick="setLabel('sitting')">Sitting</button>
  <button onclick="setLabel('standing')">Standing</button>
  <button onclick="setLabel('lying')">Lying</button>
  <button onclick="setLabel('walking')">Walking</button>
  <button onclick="setLabel('running')">Running</button>
  <button onclick="setLabel('trembling')">Trembling / Shaking</button>
</div>
<div class="custom">
  <input id="custom" placeholder="custom label" onkeydown="if(event.key==='Enter') setCustom()">
  <button onclick="setCustom()">Set</button>
</div>
<script>
function setLabel(v) { fetch('/label/' + encodeURIComponent(v)).then(refresh); }
function setCustom() { var v = document.getElementById('custom').value.trim(); if (v) setLabel(v); }
function refresh() {
  fetch('/status').then(r => r.json()).then(d => {
    document.getElementById('label').textContent = d.label;
    document.getElementById('rows').textContent = d.rows + ' rows recorded';
  });
}
refresh();
setInterval(refresh, 2000);
</script>
</body>
</html>
"""


def make_handler(writer, out_file, dog, size):
    seen = {"label": None, "rows": 0}
    page = PAGE.replace("__DOG__", dog).replace("__SIZE__", size)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass  # quiet -- only label/row confirmations should print

        def do_GET(self):
            if self.path.startswith("/label/"):
                value = unquote(self.path[len("/label/"):]).strip()
                if value:
                    state["label"] = value
                    print(f"-> label set to '{value}'")
                self._json({"ok": True, "label": state["label"]})
            elif self.path == "/status":
                self._json({"label": state["label"], "rows": seen["rows"]})
            else:
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(page.encode())

        def _json(self, obj):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(obj).encode())

        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                rows = json.loads(body)
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                return

            label = state["label"]
            if seen["label"] != label:
                print(f"** now recording with label '{label}' **")
                seen["label"] = label
            for row in rows:
                writer.writerow([time.time(), row["millis_ms"], row["accel_x"], row["accel_y"],
                                  row["accel_z"], row["gyro_x"], row["gyro_y"], row["gyro_z"],
                                  label, dog, size])
            out_file.flush()
            seen["rows"] += len(rows)
            if seen["rows"] % 200 < len(rows):  # print roughly every ~10s of data
                print(f"   ({seen['rows']} rows written so far)")
            self.send_response(200)
            self.end_headers()

    return Handler


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dog", required=True)
    ap.add_argument("--size", required=True, choices=["small", "medium", "large"])
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    out_path = Path(args.out) if args.out else Path(__file__).parent / "data" / f"{args.dog}_{int(time.time())}.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_file = open(out_path, "w", newline="", encoding="utf-8")
    writer = csv.writer(out_file)
    writer.writerow(["wall_time", "millis_ms", "accel_x", "accel_y", "accel_z",
                      "gyro_x", "gyro_y", "gyro_z", "label", "dog_name", "size_class"])

    print(f"Logging to {out_path}")
    print(f"Listening on port {args.port} -- put this machine's IP (run `ipconfig`) into the sketch's SERVER_URL")
    print(f"Open this in a browser to control labeling: http://localhost:{args.port}/")
    print("Ctrl+C to stop.")

    HTTPServer(("0.0.0.0", args.port), make_handler(writer, out_file, args.dog, args.size)).serve_forever()


if __name__ == "__main__":
    main()
