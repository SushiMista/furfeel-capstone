---
title: "Security and Privacy"
type: security-design
project: FurFeel
created: 2026-07-09
tags: [furfeel, security, privacy]
---

# Security and Privacy

## Protected Data
- User account information.
- Dog profiles.
- Clinic records.
- Telemetry history.
- Stress classifications.
- Vet notes and reports.
- Owner-submitted media/videos for supplementary assessment and communication.

## Baseline Controls
- Password hashing.
- Role-based access.
- Authenticated API requests.
- HTTPS for data transfer.
- Input validation.
- Audit trail for clinical notes and alert acknowledgements.
- Least-privilege access per clinic and owner.

## Privacy Decisions Needed
- [x] Will owner-submitted photos/videos be included in MVP? Decision: supplementary assessment/communication only, not classifier input.
- [ ] How long should telemetry be retained?
- [ ] Can data be exported for research?
- [ ] Does the thesis require formal consent wording for test participants?

## Related
- [[03 User Roles and Permissions]]
- [[09 Database Schema]]
- [[13 Testing Strategy]]
