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
import re
import uuid
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn
from pathlib import Path
from urllib.parse import unquote

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

CSV_HEADER = ["wall_time", "millis_ms", "accel_x", "accel_y", "accel_z",
              "gyro_x", "gyro_y", "gyro_z", "label", "dog_name", "size_class"]

state = {"label": "unlabeled", "paused": True}

PAGE = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>FurFeel Posture Logger</title>
<style>
body { font-family: system-ui, sans-serif; max-width: 480px; margin: 40px auto; padding: 0 16px; }
h1 { font-size: 20px; }
#conn-status { display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; border-radius: 8px; margin: 12px 0; font-size: 14px; font-weight: 500; }
.conn-strong { background: #dcfce7; color: #166534; border: 1px solid #86efac; }
.conn-fair { background: #fef9c3; color: #854d0e; border: 1px solid #fde047; }
.conn-weak { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; }
.conn-offline { background: #f3f4f6; color: #4b5563; border: 1px solid #d1d5db; }
#label { font-size: 28px; font-weight: bold; padding: 14px; background: #eef2ff; border-radius: 8px; text-align: center; margin: 16px 0; }
#rows { color: #666; margin-bottom: 4px; }
#total { color: #999; font-size: 13px; margin-bottom: 16px; }
.postures button { font-size: 16px; padding: 12px 16px; margin: 4px; border-radius: 8px; border: 1px solid #ccc; background: #fff; cursor: pointer; }
.postures button:hover { background: #eef2ff; }
.custom { margin-top: 20px; }
.custom input { font-size: 16px; padding: 10px; width: 55%; }
.custom button { font-size: 16px; padding: 10px 16px; }
</style>
</head>
<body>
<h1>FurFeel &mdash; Posture Data Logger</h1>
<div>Dog: <b id="dog-name"></b> (<span id="dog-size"></span>)</div>
<p>CSV: <span id="csv-name"></span></p>

<div id="conn-status" class="conn-offline">
  <span id="conn-text">📡 ESP32: Waiting for packets...</span>
  <span id="conn-signal">--</span>
</div>

<form id="new-session" class="custom">
  <label for="new-dog">New session — dog name</label><br>
  <input id="new-dog" required maxlength="80" placeholder="Bochi">
  <label for="new-size">Size</label>
  <select id="new-size"><option value="small">Small</option><option value="medium">Medium</option><option value="large">Large</option></select>
  <button id="create-csv" type="submit">New CSV</button>
  <p id="session-message" role="status"></p>
</form>
<div id="label">loading...</div>
<div id="rows"></div>
<div id="total"></div>
<button id="pause" onclick="setPaused(this.dataset.paused !== 'true')" style="font-size:18px;padding:12px 24px">Loading...</button>
<p id="recording" role="status"></p>
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
function setPaused(v) { fetch(v ? '/pause' : '/resume', {method: 'POST'}).then(refresh); }
function setLabel(v) { fetch('/label/' + encodeURIComponent(v)).then(refresh); }
function setCustom() { var v = document.getElementById('custom').value.trim(); if (v) setLabel(v); }
document.getElementById('new-session').addEventListener('submit', async function(event) {
  event.preventDefault();
  var button = document.getElementById('create-csv');
  var message = document.getElementById('session-message');
  button.disabled = true;
  try {
    var response = await fetch('/new-session', {method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({dog_name: document.getElementById('new-dog').value.trim(),
                            size_class: document.getElementById('new-size').value})});
    var result = await response.json();
    if (!response.ok) throw new Error(result.error || 'Could not create CSV');
    message.textContent = 'New CSV created. Choose an activity, then resume recording.';
    await refresh();
  } catch (error) { message.textContent = error.message; }
  finally { button.disabled = false; }
});
function refresh() {
  return fetch('/status').then(r => r.json()).then(d => {
    document.getElementById('dog-name').textContent = d.dog_name;
    document.getElementById('dog-size').textContent = d.size_class;
    document.getElementById('csv-name').textContent = d.csv_name;
    document.getElementById('label').textContent = d.label;
    var button = document.getElementById('pause');
    button.dataset.paused = String(d.paused);
    button.textContent = d.paused ? 'Resume recording' : 'Pause recording';
    document.getElementById('recording').textContent = d.paused ? 'Paused — incoming samples are not saved. Choose a posture, then resume.' : 'Recording — pause when the dog changes activity.';
    document.getElementById('rows').textContent = d.label_rows + ' rows / ' + d.label_seconds + 's for this label';
    document.getElementById('total').textContent = d.rows + ' rows total this session';

    // Update connection & signal status
    var connBox = document.getElementById('conn-status');
    var connText = document.getElementById('conn-text');
    var connSignal = document.getElementById('conn-signal');
    var age = d.last_packet_age;
    if (age === null || age === undefined || age > 5) {
      connBox.className = 'conn-offline';
      connText.textContent = age === null ? '📡 ESP32: Waiting for packets...' : '⚠️ ESP32: Disconnected (' + Math.round(age) + 's ago)';
      connSignal.textContent = 'Offline';
    } else {
      var rssi = d.rssi;
      var ip = d.esp_ip ? ' [' + d.esp_ip + ']' : '';
      if (rssi >= -60) {
        connBox.className = 'conn-strong';
        connText.textContent = '🟢 ESP32 Connected' + ip;
        connSignal.textContent = 'Strong (' + rssi + ' dBm)';
      } else if (rssi >= -75) {
        connBox.className = 'conn-fair';
        connText.textContent = '🟡 ESP32 Connected' + ip;
        connSignal.textContent = 'Fair (' + rssi + ' dBm)';
      } else {
        connBox.className = 'conn-weak';
        connText.textContent = '🔴 ESP32 Connected' + ip;
        connSignal.textContent = 'Weak (' + rssi + ' dBm)';
      }
    }
  });
}
refresh();
setInterval(refresh, 1000);
</script>
</body>
</html>
"""


def make_handler(writer, out_file, dog, size):
    seen = {"label": None, "rows": 0, "label_rows": 0, "label_start": None}
    conn_info = {"last_seen": None, "rssi": None, "ip": None}
    output_dir = Path(out_file.name).parent
    state.update(label="unlabeled", paused=True)

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
                label_seconds = round(seen["label_rows"] / 20, 1)
                last_age = round(time.time() - conn_info["last_seen"], 1) if conn_info["last_seen"] else None
                self._json({"label": state["label"], "paused": state["paused"], "rows": seen["rows"],
                             "label_rows": seen["label_rows"], "label_seconds": label_seconds,
                             "dog_name": dog, "size_class": size, "csv_name": Path(out_file.name).name,
                             "last_packet_age": last_age, "rssi": conn_info["rssi"], "esp_ip": conn_info["ip"]})
            else:
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(PAGE.encode())

        def _json(self, obj, status=200):
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(obj).encode())

        def do_POST(self):
            nonlocal writer, out_file, dog, size
            if self.path == "/new-session":
                try:
                    length = int(self.headers.get("Content-Length", "0"))
                    if not 0 < length <= 4096:
                        raise ValueError("Invalid request length")
                    data = json.loads(self.rfile.read(length))
                    new_dog = data.get("dog_name", "") if isinstance(data, dict) else ""
                    new_size = data.get("size_class") if isinstance(data, dict) else None
                    if not isinstance(new_dog, str):
                        raise ValueError("Enter a dog name")
                    new_dog = new_dog.strip()
                    if not 1 <= len(new_dog) <= 80 or any(ord(c) < 32 for c in new_dog):
                        raise ValueError("Dog name must be 1–80 characters without control characters")
                    if new_size not in ("small", "medium", "large"):
                        raise ValueError("Choose small, medium or large")
                except (ValueError, UnicodeDecodeError) as error:
                    self._json({"error": str(error)}, 400)
                    return
                slug = re.sub(r"[^A-Za-z0-9_-]+", "_", new_dog).strip("_") or "dog"
                new_path = output_dir / f"{slug}_{time.time_ns()}_{uuid.uuid4().hex[:8]}.csv"
                try:
                    new_file = new_path.open("x", newline="", encoding="utf-8")
                    new_writer = csv.writer(new_file)
                    new_writer.writerow(CSV_HEADER)
                    new_file.flush()
                except OSError:
                    if 'new_file' in locals():
                        new_file.close()
                    self._json({"error": "Could not create CSV; existing session is unchanged"}, 500)
                    return
                out_file.flush()
                out_file.close()
                writer, out_file, dog, size = new_writer, new_file, new_dog, new_size
                state.update(label="unlabeled", paused=True)
                seen.update(label=None, rows=0, label_rows=0, label_start=None)
                print(f"New session: {dog} ({size}) -> {new_path}")
                self._json({"ok": True, "csv_name": new_path.name})
                return
            if self.path in ("/pause", "/resume"):
                state["paused"] = self.path == "/pause"
                self._json({"ok": True, "paused": state["paused"]})
                return
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)

            # Track ESP32 incoming packet time and signal
            conn_info["last_seen"] = time.time()
            raw_rssi = self.headers.get("X-ESP32-RSSI")
            if raw_rssi:
                try:
                    conn_info["rssi"] = int(raw_rssi)
                except ValueError:
                    pass
            esp_ip = self.headers.get("X-ESP32-IP") or self.client_address[0]
            conn_info["ip"] = esp_ip

            if state["paused"]:
                self._json({"ok": True, "paused": True})
                return
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
                seen["label_rows"] = 0
                seen["label_start"] = time.time()
            for row in rows:
                writer.writerow([time.time(), row["millis_ms"], row["accel_x"], row["accel_y"],
                                  row["accel_z"], row["gyro_x"], row["gyro_y"], row["gyro_z"],
                                  label, dog, size])
            out_file.flush()
            seen["rows"] += len(rows)
            seen["label_rows"] += len(rows)
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
    writer.writerow(CSV_HEADER)
    out_file.flush()

    print(f"Logging to {out_path}")
    print(f"Listening on port {args.port} -- put this machine's IP (run `ipconfig`) into the sketch's SERVER_URL")
    print(f"Open this in a browser to control labeling: http://localhost:{args.port}/")
    print("Ctrl+C to stop.")

    ThreadedHTTPServer(("0.0.0.0", args.port), make_handler(writer, out_file, args.dog, args.size)).serve_forever()


if __name__ == "__main__":
    main()
