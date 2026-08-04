#!/usr/bin/env python3
"""Converts ml/models/posture_model.joblib into C code the ESP32 can run
on-device, via micromlgen -- posture classification runs on the device (raw
IMU data never leaves it, per docs/07), so the trained model has to become
firmware code, not a server-side call.

Run this after every retrain (ml/train_posture_model.py) to pick up new
postures, then re-upload firmware/esp32/furfeel_sensor.ino.

Usage:
    pip install micromlgen
    python ml/export_posture_model_to_arduino.py
"""
from pathlib import Path

import joblib
from micromlgen import port

MODEL_PATH = Path(__file__).parent / "models" / "posture_model.joblib"
HEADER_PATH = Path(__file__).parent.parent / "firmware" / "esp32" / "posture_model.h"


def main():
    data = joblib.load(MODEL_PATH)
    model = data["model"]
    c_code = port(model, classmap={i: c for i, c in enumerate(model.classes_)})

    header = f"""// GENERATED FILE -- do not hand-edit.
// Produced by ml/export_posture_model_to_arduino.py from {MODEL_PATH.name}
// Classes: {list(model.classes_)}
// Feature order (must match capturePostureWindow() in furfeel_sensor.ino
// exactly): {data['feature_names']}

{c_code}"""
    HEADER_PATH.write_text(header)
    print(f"Wrote {HEADER_PATH} ({len(header)} bytes)")
    print(f"Classes in this model: {list(model.classes_)}")
    print("Re-upload firmware/esp32/furfeel_sensor.ino to the ESP32 to deploy it.")


if __name__ == "__main__":
    main()
