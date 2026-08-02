#!/usr/bin/env python3
"""Trains the IMU posture/activity Random Forest from ml/data/*.csv (produced
by imu_wifi_logger_server.py). Windows raw 20Hz accel/gyro samples into
~1-second chunks, extracts simple statistical features per window, trains,
and reports accuracy/precision/recall/confusion matrix/feature importance
(docs/08 AI Classification Pipeline evaluation approach).

Rerun this exact script whenever new posture data is added -- it always
retrains from everything currently in ml/data/, no code changes needed to
add a posture: just collect data for it and run this again.

Usage:
    python ml/train_posture_model.py
"""
import glob
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split

WINDOW_SIZE = 20  # ~1s at 20Hz (docs/07 IMU sampling rate)
AXES = ["accel_x", "accel_y", "accel_z", "gyro_x", "gyro_y", "gyro_z"]
DATA_DIR = Path(__file__).parent / "data"
MODEL_PATH = Path(__file__).parent / "models" / "posture_model.joblib"


def load_labeled_rows():
    frames = []
    for path in sorted(glob.glob(str(DATA_DIR / "*.csv"))):
        df = pd.read_csv(path)
        df = df[df["label"] != "unlabeled"]
        if df.empty:
            continue
        df = df.sort_values("millis_ms").reset_index(drop=True)
        # a contiguous run of the same label within one file = one recording
        # block; windows never span two different labels or two files.
        df["block"] = (df["label"] != df["label"].shift()).cumsum()
        df["source_file"] = Path(path).stem
        frames.append(df)
    if not frames:
        raise SystemExit("No labeled rows found in ml/data/*.csv -- nothing to train on.")
    return pd.concat(frames, ignore_index=True)


def window_features(df):
    rows = []
    for (source_file, block), group in df.groupby(["source_file", "block"]):
        label = group["label"].iloc[0]
        values = group[AXES].to_numpy()
        n_windows = len(values) // WINDOW_SIZE
        for w in range(n_windows):
            chunk = values[w * WINDOW_SIZE:(w + 1) * WINDOW_SIZE]
            feats = {}
            for i, axis in enumerate(AXES):
                col = chunk[:, i]
                feats[f"{axis}_mean"] = col.mean()
                feats[f"{axis}_std"] = col.std()
                feats[f"{axis}_min"] = col.min()
                feats[f"{axis}_max"] = col.max()
            accel_mag = np.sqrt((chunk[:, 0] ** 2 + chunk[:, 1] ** 2 + chunk[:, 2] ** 2))
            feats["accel_mag_mean"] = accel_mag.mean()
            feats["accel_mag_std"] = accel_mag.std()
            feats["label"] = label
            rows.append(feats)
    return pd.DataFrame(rows)


def main():
    raw = load_labeled_rows()
    print("Rows per label (raw, pre-windowing):")
    print(raw["label"].value_counts().to_string())
    print()

    features = window_features(raw)
    print("Training windows per label (1 window =~ 1s of data):")
    print(features["label"].value_counts().to_string())
    print()

    MIN_WINDOWS_PER_CLASS = 10  # need at least a few for a meaningful train/test split
    class_counts = features["label"].value_counts()
    too_sparse = class_counts[class_counts < MIN_WINDOWS_PER_CLASS]
    if not too_sparse.empty:
        print(f"Excluding from this run (too little data yet, <{MIN_WINDOWS_PER_CLASS} windows): "
              + ", ".join(f"{label} ({count})" for label, count in too_sparse.items()))
        print("Collect more for these and rerun this same script to add them back in.\n")
        features = features[~features["label"].isin(too_sparse.index)]

    class_counts = features["label"].value_counts()
    if len(class_counts) < 2:
        raise SystemExit("Fewer than 2 postures have enough data -- need at least 2 to train a classifier.")

    X = features.drop(columns=["label"])
    y = features["label"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = RandomForestClassifier(
        n_estimators=100, criterion="gini", max_depth=None, bootstrap=True, random_state=42
    )
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)

    print(f"Test set: {len(y_test)} windows ({len(y_train)} used for training)")
    print(f"Accuracy: {accuracy_score(y_test, y_pred):.3f}\n")
    print("Precision / recall / F1 per class:")
    print(classification_report(y_test, y_pred))
    print("Confusion matrix (rows=actual, cols=predicted):")
    labels = sorted(y.unique())
    cm = confusion_matrix(y_test, y_pred, labels=labels)
    print("        " + "  ".join(f"{l:>10s}" for l in labels))
    for label, row in zip(labels, cm):
        print(f"{label:>8s} " + "  ".join(f"{v:>10d}" for v in row))
    print()

    importances = pd.Series(model.feature_importances_, index=X.columns).sort_values(ascending=False)
    print("Top feature importances:")
    print(importances.head(10).to_string())

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model, "feature_names": list(X.columns), "classes": list(model.classes_)}, MODEL_PATH)
    print(f"\nSaved model to {MODEL_PATH}")


if __name__ == "__main__":
    main()
