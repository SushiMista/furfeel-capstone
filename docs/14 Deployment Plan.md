---
title: "Deployment Plan"
type: deployment
project: FurFeel
created: 2026-07-09
tags: [furfeel, deployment, operations]
---

# Deployment Plan

## Environments
- Local development.
- Testing/staging.
- Pilot deployment.
- Production, if the project reaches commercialization.

## Deployment Units
- ESP32 firmware.
- Backend API.
- Database.
- AI model artifact.
- Mobile app.
- Web dashboard.

## Pilot Deployment Flow
1. Register clinic.
2. Register test dog.
3. Pair wearable device.
4. Confirm telemetry reaches backend.
5. Confirm classification appears.
6. Confirm alert behavior.
7. Collect feedback from users.

## Operations Questions
- [ ] Who maintains the backend during testing?
- [ ] Where will the database be hosted?
- [ ] How will model updates be deployed?
- [ ] How will firmware updates be handled?

## Related
- [[17 Market and Go To Market]]
- [[18 Three Year Product Roadmap]]
