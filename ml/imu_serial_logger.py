#!/usr/bin/env python3
"""Capture imu_logger.ino's raw CSV stream and tag it with a posture label
you type live while the dog does that activity. No Wi-Fi/Supabase involved --
bench collection only (docs: ml/README.md, Phase 1 posture model).

Usage:
    pip install pyserial
    python ml/imu_serial_logger.py COM5 --dog Mochi --size small

While it runs: type a posture label + Enter any time the dog's activity
changes (e.g. "sitting", "standing", "walking", "running", "trembling").
Every row received after that gets tagged with the latest label, until you
change it again. Ctrl+C to stop -- the CSV is flushed after every row.
"""
import argparse
import csv
import sys
import threading
import time
from pathlib import Path

import serial

def parse_imu_line(line: str):
    """Parse one 'millis,ax,ay,az,gx,gy,gz' line from imu_logger.ino. Returns
    a dict or None if the line isn't a data row (e.g. the CSV header)."""
    parts = line.strip().split(",")
    if len(parts) != 7:
        return None
    try:
        values = [float(p) for p in parts]
    except ValueError:
        return None
    keys = ["millis_ms", "accel_x", "accel_y", "accel_z", "gyro_x", "gyro_y", "gyro_z"]
    return dict(zip(keys, values))

def label_input_loop(state: dict, lock: threading.Lock):
    while True:
        typed = sys.stdin.readline().strip()
        if not typed:
            continue
        with lock:
            state["label"] = typed
        print(f"-> label set to '{typed}'")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", help="Serial port, e.g. COM5")
    ap.add_argument("--dog", required=True)
    ap.add_argument("--size", required=True, choices=["small", "medium", "large"])
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--out", default=None, help="Output CSV path (default: ml/data/<dog>_<timestamp>.csv)")
    args = ap.parse_args()

    out_path = Path(args.out) if args.out else Path(__file__).parent / "data" / f"{args.dog}_{int(time.time())}.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    state = {"label": "unlabeled"}
    lock = threading.Lock()
    threading.Thread(target=label_input_loop, args=(state, lock), daemon=True).start()

    print(f"Logging to {out_path}")
    print("Type a posture label + Enter whenever the dog's activity changes. Ctrl+C to stop.")

    with serial.Serial(args.port, args.baud, timeout=1) as ser, \
         open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["wall_time", "millis_ms", "accel_x", "accel_y", "accel_z",
                          "gyro_x", "gyro_y", "gyro_z", "label", "dog_name", "size_class"])
        while True:
            raw = ser.readline().decode("utf-8", errors="ignore")
            row = parse_imu_line(raw)
            if row is None:
                continue
            with lock:
                label = state["label"]
            writer.writerow([time.time(), row["millis_ms"], row["accel_x"], row["accel_y"],
                              row["accel_z"], row["gyro_x"], row["gyro_y"], row["gyro_z"],
                              label, args.dog, args.size])
            f.flush()

def _self_check():
    assert parse_imu_line("millis_ms,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z") is None
    row = parse_imu_line("1234,0.01,-0.02,0.98,1.5,-0.3,0.2")
    assert row == {"millis_ms": 1234.0, "accel_x": 0.01, "accel_y": -0.02,
                    "accel_z": 0.98, "gyro_x": 1.5, "gyro_y": -0.3, "gyro_z": 0.2}
    assert parse_imu_line("garbage") is None
    print("self-check ok")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-check":
        _self_check()
    else:
        main()
