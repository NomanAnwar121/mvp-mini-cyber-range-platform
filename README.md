# mvp-mini-cyber-range-platform
# VulnLab Cyber Range MVP

## Project Title

**VulnLab Cyber Range MVP: Attack Simulation, Skills Assessment, and Training Automation for Cybersecurity Education**

## 1. Project Overview

This project is a lightweight cyber range platform built for cybersecurity education. It provides a safe training environment where learners can practice common web attacks, submit flags, receive automatic scoring, and review their performance analytics.

The platform is designed as an MVP (Minimum Viable Product) version of a larger cyber range system. Instead of building a full enterprise-grade infrastructure with Kubernetes, CALDERA, GNS3, or a complete LMS, this project focuses on the core educational features in a small, practical, and easy-to-demonstrate system.

The application currently includes:

* hands-on web security labs
* reflected and stored attack simulation
* MITRE ATT&CK mapping
* campaign orchestration simulation
* automated flag validation and scoring
* learner analytics and skill tracking
* leaderboard-based CTF workflow

This makes the project suitable for demonstrating the main ideas of Topic 80 while staying realistic for student implementation.

---

## 2. Main Objective

The main objective of this project is to build a mini cyber range that helps learners:

* understand how common web vulnerabilities work
* practice exploitation in a controlled environment
* receive automatic feedback and scoring
* track progress and identify weak areas
* explore how attack campaigns are structured using MITRE ATT&CK concepts

---

## 3. Current Feature Set

### 3.1 User Login and Session Management

The platform allows users to log in with a username. A session is created and the learner’s progress is stored in SQLite.

**Purpose:**

* identify each learner
* store scores and attempts
* enable individual analytics

### 3.2 SQL Injection Lab

This lab simulates a vulnerable login form. The learner can attempt authentication bypass using SQL injection payloads.

**Current behavior:**

* user enters username and password payload
* the app builds an unsafe SQL query preview
* a correct SQLi payload reveals a flag
* the learner submits the flag to earn points

**Learning outcome:**

* understand insecure query construction
* learn authentication bypass logic
* practice a common web exploitation technique

### 3.3 Reflected XSS Lab

This lab uses a real URL query parameter such as:

```text
/lab/xss?q=welcome
```

The learner can manipulate the `q` parameter and test reflected XSS payloads.

**Current behavior:**

* the page reflects input unsafely
* the learner tries script payloads
* a successful payload reveals a flag

**Learning outcome:**

* understand reflected XSS
* learn unsafe output rendering
* observe how URL parameters can be abused

### 3.4 Stored XSS Lab

This lab simulates a blog/comment system.

**Current behavior:**

* the learner submits a comment
* comments are stored in the database
* comments are rendered unsafely
* a successful script payload reveals a flag

**Learning outcome:**

* understand stored XSS
* learn persistent client-side injection behavior
* compare stored vs reflected XSS

### 3.5 IDOR Lab

This lab uses a real URL object reference such as:

```text
/lab/idor?id=1001
```

The learner starts from normal demo data and manually changes the ID in the URL.

**Current behavior:**

* clicking Open IDOR opens with `?id=1001`
* normal records belong to the user
* changing the ID exposes unauthorized records
* record `id=1004` contains the hidden flag

**Learning outcome:**

* understand broken access control / IDOR
* learn how predictable object IDs can expose sensitive data
* practice direct URL-based exploitation

### 3.6 Flag Submission and CTF Workflow

The platform follows a CTF-style model.

**Current behavior:**

* each solved lab reveals a flag
* learner submits the flag on the Flags page
* the system validates the flag automatically
* points are added to the learner score

**Learning outcome:**

* encourage engagement through gamification
* automate evaluation without manual grading
* simulate capture-the-flag training workflows

### 3.7 Automated Scoring

The application awards points automatically after correct flag submission.

**Purpose:**

* remove manual checking
* provide immediate feedback
* support objective assessment

### 3.8 Attempt Tracking

The platform stores lab attempts in the database.

**Tracked values include:**

* challenge ID
* submitted payload or value
* whether the attempt succeeded
* timestamp

**Purpose:**

* measure learner persistence
* support analytics
* identify weak areas

### 3.9 Learner Analytics

The Analytics page provides simple performance monitoring.

**Current analytics include:**

* challenge attempts
* number of successes
* completion status
* current score
* recommendation for what to study next

**Purpose:**

* support skills assessment
* provide competency tracking
* help instructors and learners understand progress

### 3.10 Training Automation

The platform includes small automation features for educational support.

**Current automation includes:**

* automatic hints after repeated failed attempts
* automatic scoring
* automatic attempt recording
* recommendation of skill areas to focus on

**Purpose:**

* make learning adaptive
* improve learner guidance
* reduce instructor workload

### 3.11 MITRE ATT&CK Mapping

Each lab is mapped to a related MITRE ATT&CK technique or concept.

**Purpose:**

* connect classroom exercises with real-world attacker behavior
* improve academic relevance
* help students explain attacks using industry language

### 3.12 Campaign Orchestration

The platform includes a Campaigns module that simulates red team exercise orchestration.

**Current behavior:**

* learner opens a campaign
* campaign displays phases and MITRE ATT&CK mappings
* running the campaign stores execution logs in the database
* logs show each phase and attack step

**Important note:**
This is currently an educational simulation of attack orchestration, not a full CALDERA deployment.

**Purpose:**

* demonstrate automated adversary emulation concepts
* show red team workflow stages
* support presentation and interview discussion

### 3.13 Leaderboard

The platform includes a leaderboard to rank learners by score.

**Purpose:**

* add motivation and competition
* support CTF-style training
* visualize learner performance

---

## 4. Project Architecture

The current project is built as a Flask web application with SQLite storage.

### 4.1 Backend

* Python
* Flask
* SQLite

### 4.2 Frontend

* HTML templates (Jinja2)
* CSS

### 4.3 Database Tables

The platform currently uses database tables for:

* users
* task submissions
* challenge attempts
* campaign runs
* campaign run steps
* stored comments

### 4.4 Application Modules

* Login module
* Dashboard module
* Labs module
* Flag submission module
* Analytics module
* Campaign module
* Leaderboard module

---

## 5. How the Labs Work

### 5.1 SQL Injection Workflow

1. User opens SQLi lab
2. User enters login payload
3. App shows unsafe query preview
4. Successful payload reveals flag
5. User submits flag
6. Score is updated

### 5.2 Reflected XSS Workflow

1. User opens reflected XSS lab with a query parameter
2. User modifies `q` in the URL or search box
3. App reflects the input unsafely
4. Valid payload reveals flag
5. User submits flag

### 5.3 Stored XSS Workflow

1. User opens stored XSS lab
2. User posts a comment payload
3. Comment is saved in DB
4. App renders stored input unsafely
5. Valid payload reveals flag
6. User submits flag

### 5.4 IDOR Workflow

1. User opens IDOR lab with `?id=1001`
2. User sees own demo object
3. User changes URL manually to other IDs
4. Unauthorized record is exposed
5. Flag is found in `id=1004`
6. User submits flag

---

## 6. Comparison With Topic 80

Below is a comparison between the requested topic and the current implementation.

## 6.1 Topic Requirement: Virtualized Attack and Defense Environment

**Topic asks for:**

* containerized and virtualized environments
* vulnerable applications and systems
* realistic training targets

**Current project status:**

* partially implemented
* the current project provides vulnerable application behavior inside a Flask web app
* it does not currently use Docker, VirtualBox, Kubernetes, GNS3, or EVE-NG in the live version

**How this project matches the topic:**

* it provides a safe vulnerable training application
* it simulates real web exploitation scenarios

**Future upgrade path:**

* package labs with Docker
* deploy separate vulnerable containers
* isolate labs per user

## 6.2 Topic Requirement: Automated Attack Simulation and Red Team Exercises

**Topic asks for:**

* CALDERA or Atomic Red Team style attack emulation
* MITRE ATT&CK orchestration
* dynamic scenario generation

**Current project status:**

* partially implemented
* MITRE ATT&CK mapping is included
* attack simulation pages are included
* campaign orchestration is included
* execution logs are included
* real CALDERA/Atomic Red Team deployment is not yet integrated

**How this project matches the topic:**

* demonstrates the architecture and concept of adversary emulation
* provides safe educational attack campaigns
* supports presentation of red team exercise flow

**Future upgrade path:**

* integrate Atomic Red Team tests
* connect campaigns to live lab steps
* add dynamic campaign branching

## 6.3 Topic Requirement: Skills Assessment and Performance Analytics

**Topic asks for:**

* automated assessment
* progress analytics
* skill gap analysis

**Current project status:**

* implemented at MVP level
* automatic flag validation is present
* scoring is present
* attempts and success counts are tracked
* recommendations are generated

**How this project matches the topic:**

* strong match for MVP scope
* provides measurable learner data
* gives progress visibility and automated feedback

**Future upgrade path:**

* add instructor dashboard
* add certification pathway mapping
* add more detailed skill-gap analytics

## 6.4 Topic Requirement: Training Content Management and Delivery

**Topic asks for:**

* LMS integration
* lab provisioning
* personalized learning paths

**Current project status:**

* partially implemented
* training content is embedded in the lab pages
* recommendations and hints provide basic personalization
* LMS integration is not yet implemented

**How this project matches the topic:**

* delivers guided practical learning content
* uses hints and recommendations for learner support

**Future upgrade path:**

* integrate Moodle or Canvas
* add instructor lesson modules
* add SCORM-style export or LMS linking

## 6.5 Topic Requirement: Collaboration and Team-Based Exercises

**Topic asks for:**

* multi-user collaboration
* team exercises
* CTF platform with scoring
  n**Current project status:**
* partially implemented
* multiple users can use the platform independently
* leaderboard exists
* CTF-style scoring exists
* team mode is not yet implemented

**How this project matches the topic:**

* supports individual learner competition
* already uses flag-based automated scoring

**Future upgrade path:**

* add team mode
* add shared team scoreboards
* add challenge discussion or collaboration features

## 6.6 Topic Requirement: Platform Administration and Scalability

**Topic asks for:**

* Kubernetes
* autoscaling
* monitoring
* performance optimization

**Current project status:**

* not implemented in the MVP
* current system is single-node Flask + SQLite

**How this project matches the topic:**

* architecture can be explained as an MVP prototype
* core educational logic is demonstrated first

**Future upgrade path:**

* move to PostgreSQL
* containerize the app with Docker
* deploy with Kubernetes
* add monitoring and metrics collection

---

## 7. Strengths of the Current MVP

The current project is strong in the following areas:

* practical and easy to demonstrate
* realistic enough for web exploitation education
* supports multiple core security topics
* includes attack simulation and analytics
* uses automatic flag validation
* clearly connects labs to topic requirements
* easy to explain during presentation and interview

---

## 8. Current Limitations

This project is still an MVP, so some parts are simplified.

### Current limitations include:

* no Docker-based lab isolation in the live version
* no full CALDERA or Atomic Red Team integration
* no network simulation with GNS3 or EVE-NG
* no LMS integration yet
* no team collaboration mode yet
* no instructor/admin control panel yet
* no cloud scalability layer yet

These limitations are acceptable for an MVP because the platform already demonstrates the core educational concepts.

---

## 9. Future Improvements

To align even more closely with Topic 80, the next upgrades should be:

### 9.1 Infrastructure Enhancements

* package labs in Docker containers
* isolate user lab environments
* add optional Kubernetes deployment

### 9.2 More Labs

* broken authentication
* file upload vulnerability
* command injection
* CSRF
* SSRF

### 9.3 Better Attack Simulation

* integrate Atomic Red Team
* add dynamic campaigns
* connect campaigns directly to hands-on labs

### 9.4 Better Analytics

* instructor dashboard
* learner progress charts
* skill-gap reports
* certification pathway mapping

### 9.5 Training Delivery

* add lesson pages and quizzes
* integrate with Moodle or Canvas
* support adaptive learning paths

### 9.6 Collaboration

* teams and team scoreboards
* shared campaign progress
* challenge notes and discussion

---

## 10. Industry Relevance

This kind of platform is useful for:

* universities and colleges
* cybersecurity bootcamps
* enterprise training teams
* internal awareness programs
* beginner red team practice
* web security lab teaching

It matches industry needs because modern security education requires:

* practical training
* repeatable exercises
* objective assessment
* analytics-driven improvement

---

## 11. How to Demonstrate the Project

A good demo sequence is:

1. log in as a learner
2. open dashboard
3. show SQLi lab
4. show reflected XSS lab with `?q=`
5. show stored XSS comment lab
6. show IDOR lab with `?id=1001`
7. manually change ID to `1004`
8. reveal flags
9. submit flags
10. show score update
11. open analytics
12. show campaigns and execution logs
13. show leaderboard

---

## 12. How to Explain It in Presentation

A simple explanation is:

> This project is a lightweight cyber range platform for cybersecurity education. It gives learners a safe place to practice common web attacks such as SQL Injection, reflected XSS, stored XSS, and IDOR. The platform reveals flags after successful exploitation, validates them automatically, and records learner performance through scoring, analytics, and campaign tracking. It also includes MITRE ATT&CK mapping and safe red team exercise orchestration to demonstrate the broader cyber range concept from Topic 80.

---

## 13. How to Explain It in Interview

If asked whether it fully matches the topic, the honest answer is:

> This project implements the core educational layer of the topic as an MVP. It strongly covers attack simulation, skills assessment, automated scoring, CTF workflow, learner analytics, and ATT&CK-based campaign orchestration. Infrastructure-heavy components such as Docker-based lab isolation, CALDERA integration, LMS integration, and Kubernetes scalability are planned as future extensions.

---

## 14. Setup and Run

From the project folder:

```bash
python3 app.py
```

Open in browser:

```text
http://127.0.0.1:5000
```

Useful lab URLs:

```text
/lab/sqli
/lab/xss?q=welcome
/lab/stored-xss
/lab/idor?id=1001
```

---

## 15. Sample Test Inputs

### SQL Injection

Use:

```text
username: admin
password: ' OR '1'='1
```

### Reflected XSS

Use:

```html
<script>alert(1)</script>
```

inside the `q` parameter.

### Stored XSS

Post this as a comment:

```html
<script>alert(1)</script>
```

### IDOR

Start with:

```text
/lab/idor?id=1001
```

Then change it to:

```text
/lab/idor?id=1004
```

---

## 16. Final Summary

This project is a practical MVP of a cyber range platform. It does not yet include the full infrastructure of an enterprise cyber range, but it successfully demonstrates the most important educational features of Topic 80:

* realistic attack labs
* automated assessment
* training automation
* performance analytics
* ATT&CK-mapped simulation
* campaign orchestration
* CTF-style scoring and learner engagement

It is a solid base for further expansion into a more comprehensive cyber range platform.
