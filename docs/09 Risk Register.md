---
title: "Risk Register"
type: risk-register
project: FurFeel
created: 2026-07-09
tags: [furfeel, risks, project-management]
---

# Risk Register

## Risk Levels
- Low: manageable with normal planning.
- Medium: may delay development if ignored.
- High: can block MVP or defense claims.

## Active Risks

### Hardware Not Yet Established
Level: Medium

Impact: Real telemetry may be delayed, but software development can continue with simulated telemetry.

Mitigation:
- [x] Build simulator first.
- [ ] Keep ESP32 payload format identical to simulator payload.
- [ ] Document hardware limitations honestly.

### No Expert-Labeled Dataset Yet
Level: High

Impact: Random Forest cannot be defended as trained/validated yet.

Mitigation:
- [ ] Use rule-based classifier for MVP.
- [ ] Document it as interim logic.
- [ ] Prepare expert validation plan.

### Rule-Based Classification Validity
Level: Medium

Impact: Stress labels may be questioned during defense.

Mitigation:
- [ ] Record rule sources and assumptions.
- [ ] Let veterinarians review threshold logic.
- [ ] Avoid claiming clinical diagnosis.

### Supabase Security Misconfiguration
Level: Medium

Impact: Users may access records they should not see.

Mitigation:
- [ ] Enable Row Level Security early.
- [ ] Test owner vs clinic permissions.
- [ ] Avoid public tables for sensitive records.

### Time Split Across Mobile, Web, Hardware, AI
Level: High

Impact: Too many surfaces may make all of them shallow.

Mitigation:
- [ ] Build one vertical slice first.
- [ ] Use simple screens before complex dashboards.
- [ ] Track scope with [[16 MVP Development Plan]].

## Review Rhythm
Update this register after every major adviser meeting or sprint review.
