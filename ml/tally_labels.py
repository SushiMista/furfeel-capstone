#!/usr/bin/env python3
"""Count phase1_data_collection_template.csv rows by stress_label.
Run after each session to check progress against the Phase 1 gate
(every label needs more than a handful of real rows, "high" especially).

Usage: python ml/tally_labels.py [path/to/csv]
"""
import csv
import sys
from collections import Counter

path = sys.argv[1] if len(sys.argv) > 1 else "ml/phase1_data_collection_template.csv"

counts = Counter()
with open(path, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        counts[row["stress_label"]] += 1

for label in ["calm", "mild", "moderate", "high"]:
    print(f"{label:10s} {counts.get(label, 0)}")
print(f"{'total':10s} {sum(counts.values())}")
