---
title: "User Roles and Permissions"
type: access-control
project: FurFeel
created: 2026-07-09
tags: [furfeel, security, users]
---

# User Roles and Permissions

## Roles

### Dog Owner
- View owned dogs.
- View current stress status.
- View telemetry summaries.
- Receive alerts.
- Submit notes, photos, or videos if supported.

### Veterinary Staff
- View assigned clinic dogs.
- Monitor real-time readings.
- Acknowledge alerts.
- Add observations.
- Assist with device setup.

### Veterinarian
- All veterinary staff permissions.
- Review history and reports.
- Add recommendations.
- Confirm or override stress assessments.

### Admin
- Manage users.
- Manage clinics.
- Manage devices.
- View system health.

## Permission Questions
- [ ] Can one dog belong to multiple owners?
- [ ] Can an owner share a dog record with a clinic temporarily?
- [ ] Can clinic staff see dogs outside their clinic?
- [ ] Who can delete telemetry or reports?

## Related
- [[12 Security and Privacy]]
- [[09 Database Schema]]
