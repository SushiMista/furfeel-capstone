---
title: "System Design and Architecture Index"
type: architecture-index
project: FurFeel
created: 2026-07-09
tags: [furfeel, architecture, development-guide]
---

# System Design and Architecture Index

> [!summary]
> This group is the developer-facing guide for building FurFeel. It translates the manuscript brain into practical system structure, modules, decisions, schemas, APIs, pipelines, testing, and deployment notes.

## Build Guide
- [[01 System Overview]]
- [[02 Architecture Decisions]]
- [[03 User Roles and Permissions]]
- [[04 Mobile App Design]]
- [[05 Veterinary Dashboard Design]]
- [[06 IoT Wearable Device Design]]
- [[07 Sensor Data Pipeline]]
- [[08 AI Classification Pipeline]]
- [[09 Database Schema]]
- [[10 API and Backend Services]]
- [[11 Alerts and Notifications]]
- [[12 Security and Privacy]]
- [[13 Testing Strategy]]
- [[14 Deployment Plan]]
- [[15 Open Technical Questions]]
- [[16 MVP Development Plan]]
- [[17 Technology Stack]]
- [[18 Repository Structure]]
- [[19 Design System]]

## Source Brain Links
- [[00 FurFeel Project Bible]]
- [[06 System Architecture]]
- [[07 IoT Wearable Harness]]
- [[08 Sensor Data Model]]
- [[09 AI Stress Classification]]
- [[10 Mobile App]]
- [[11 Veterinary Dashboard]]
- [[12 Cloud Database and Data Flow]]
- [[15 Testing and Evaluation Plan]]
- [[20 Development Backlog]]

## Current Build Priority
1. Lock the MVP scope in [[16 MVP Development Plan]].
2. Confirm assumptions in [[15 Open Technical Questions]].
3. Build the telemetry loop from ESP32 Wi-Fi to Supabase.
4. Build simple Flutter mobile and React dashboard views around real data.
5. Add rule-based stress classification first, then evolve toward Random Forest after expert validation.
