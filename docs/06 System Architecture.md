---
title: "System Architecture"
type: architecture
project: FurFeel
source: Capstone1_FinalManuscript
created: 2026-07-09
tags: [furfeel, architecture]
---

# System Architecture

## Architecture Model
The manuscript describes a three-tier architecture: presentation, logic, and data tiers.

## Source Notes
- Figure 1 presents the conceptual framework that guides the development of the proposed project, FurFeel: A Canine Stress Classification and Monitoring System Using Biotelemetry and Random Forest Model for Clinical and Home Environments. The framework follows an Issue–Input–Process–Output–Feedback/Evaluation model to clearly illustrate the relationships among the identified problem, system requirements, processing stages, expected outputs, and the evaluation of the proposed system.
- The framework begins by identifying the issue, highlighting the challenges of canine stress monitoring in veterinary and caregiving settings. Existing methods largely depend on manual observation, which may lead to delayed or inconsistent identification of canine stress. Because stress indicators may appear subtly or vary among dogs, there is a need for a more objective, real-time monitoring system to support early detection and improve canine welfare.
- Following the identified issue, the input comprises the data and software requirements necessary to develop the proposed system. These include physiological and environmental sensor inputs such as heart rate, motion, restlessness, and body temperature. The input also includes software requirements such as the mobile application, web dashboard, cloud database, machine learning model, and IoT communication protocols that support monitoring and system operation.
- The process involves FurFeel's AI-based stress classification workflow. The gathered sensor inputs are processed through the machine learning component using Random Forest algorithms to analyze patterns from the collected physiological and environmental data. Based on the analysis, the system classifies canine stress levels as low, moderate, or high, which serves as the basis for system monitoring and alerts.
- After the processing stage, the expected output of the study is a real-time canine stress classification and monitoring system capable of providing immediate stress-level results, live monitoring with alert notifications for abnormal conditions, and veterinary support through faster response and improved canine care.
- Lastly, the feedback and evaluation component ensures the effectiveness and quality of the proposed system. The system will be evaluated against ISO/IEC 25010 for functional suitability, performance efficiency, usability, reliability, compatibility, and security. The results of the evaluation will be used to assess the system’s performance and determine possible improvements to enhance FurFeel’s reliability and usability for real-time canine monitoring.
- Figure 1
- System Architecture is a conceptual model that defines the structure, behavior, and overall view of the proposed system. The researchers used a three-tier architecture comprising the presentation, logic, and data tiers to organize the major functions and interactions of FurFeel.

## Tier Breakdown
- Presentation tier: mobile app and web dashboard.
- Logic tier: ESP32, sensors, data collection, preprocessing, and AI classification workflow.
- Data tier: cloud database for users, dogs, telemetry, monitoring history, and records.

## Interfaces
- [[10 Mobile App]]
- [[11 Veterinary Dashboard]]
- [[12 Cloud Database and Data Flow]]
- [[09 AI Stress Classification]]

## Related
- [[01 Unified Project Idea]]
- [[07 IoT Wearable Harness]]
