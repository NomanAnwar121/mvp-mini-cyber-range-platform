# mvp-mini-cyber-range-platform
# VulnLab Cyber Range MVP

## Project Title
**VulnLab Cyber Range MVP: Attack Simulation, Skills Assessment, and Training Automation for Cybersecurity Education**

## 1. Project Overview
This project is a lightweight cyber range platform built for cybersecurity education. It provides a safe training environment where learners can practice common web attacks, submit flags, receive automatic scoring, and review their performance analytics.

The platform is designed as an MVP (Minimum Viable Product) version of a larger cyber range system. Instead of building a full enterprise-grade infrastructure with Kubernetes, CALDERA, GNS3, or a complete LMS, this project focuses on the core educational features in a small, practical, and easy-to-demonstrate system.

The application currently includes:
- hands-on web security labs
- reflected and stored attack simulation
- MITRE ATT&CK mapping
- campaign orchestration simulation
- automated flag validation and scoring
- learner analytics and skill tracking
- leaderboard-based CTF workflow

This makes the project suitable for demonstrating the main ideas of Topic 80 while staying realistic for student implementation.

---

## 2. Main Objective
The main objective of this project is to build a mini cyber range that helps learners:
- understand how common web vulnerabilities work
- practice exploitation in a controlled environment
- receive automatic feedback and scoring
- track progress and identify weak areas
- explore how attack campaigns are structured using MITRE ATT&CK concepts

---

## 3. Current Feature Set

### 3.1 User Login and Session Management
The platform allows users to log in with a username. A session is created and the learner’s progress is stored in SQLite.

**Purpose:**
- identify each learner
- store scores and attempts
- enable individual analytics

### 3.2 SQL Injection Lab
This lab simulates a vulnerable login form. The learner can attempt authentication bypass using SQL injection payloads.

**Current behavior:**
- user enters username and password payload
- the app builds an unsafe SQL query preview
- a correct SQLi payload reveals a flag
- the learner submits the flag to earn points

**Learning outcome:**
- understand insecure query construction
- learn authentication bypass logic
- practice a common web exploitation technique

### 3.3 Reflected XSS Lab
This lab uses a real URL query parameter such as:

```text
/lab/xss?q=welcome
