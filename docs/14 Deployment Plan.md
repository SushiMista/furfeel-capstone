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

## Android app identity + versioning (as built)
| Field | Value | Where |
|---|---|---|
| App label | `FurFeel` | `android/app/src/main/AndroidManifest.xml` |
| Application ID | `com.furfeel.furfeel_mobile` | `android/app/build.gradle.kts` |
| Version | `1.0.0+2` → versionName `1.0.0`, versionCode `2` | `apps/mobile/pubspec.yaml` |
| Launcher icon | `apps/mobile/assets/icon/app_icon.png` → generated `mipmap-*/ic_launcher.png` | — |

Gradle reads `versionCode`/`versionName` straight from Flutter, so **`pubspec.yaml` is the single place a release is versioned**. Bump the build number (`+N`) for every APK handed to a tester — Android refuses to install a build whose `versionCode` is not higher than the installed one, which otherwise reads as "the update didn't work."

The launcher icon is also what Android 12+ paints on the system launch screen, so changing it changes the first frame of the app — see `04 Mobile App Design` → Launch + splash, and ADR-019.

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
