#!/bin/bash

set -e

echo "======================================"
echo " Upgrading labs to more realistic vulnerable pages"
echo "======================================"

mkdir -p templates
mkdir -p static

echo "[+] Writing app.py ..."
cat > app.py <<'EOF'
import os
import sqlite3
from flask import Flask, render_template, request, redirect, session, url_for, flash, abort

app = Flask(__name__)
app.secret_key = "mini-cyber-range-secret-key"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_NAME = os.path.join(BASE_DIR, "cyber_range.db")

CHALLENGES = [
    {
        "id": "sqli",
        "title": "SQL Injection Lab",
        "description": "Exploit an unsafe login query to bypass authentication.",
        "difficulty": "Easy",
        "category": "Web Security",
        "skill_area": "Injection Attacks",
        "mitre": "T1190 - Exploit Public-Facing Application",
        "flag": "FLAG{SQLI_MASTER}",
        "points": 10,
        "simulation_steps": [
            "Recon: inspect the login form",
            "Probe: submit a single quote to trigger an SQL error",
            "Exploit: use an authentication bypass payload",
            "Access: obtain unauthorized admin access",
            "Capture: retrieve the challenge flag"
        ],
        "hint1": "Try putting a single quote in the password field first.",
        "hint2": "Use username admin and test a condition that always evaluates true."
    },
    {
        "id": "xss",
        "title": "Reflected XSS Lab",
        "description": "Exploit unsafe reflection in a search page.",
        "difficulty": "Easy",
        "category": "Web Security",
        "skill_area": "Client-Side Attacks",
        "mitre": "T1059.007 - JavaScript",
        "flag": "FLAG{XSS_HUNTER}",
        "points": 10,
        "simulation_steps": [
            "Recon: inspect reflected search input",
            "Probe: confirm input is echoed back into HTML",
            "Exploit: inject a script or event handler payload",
            "Execution: trigger client-side code execution",
            "Capture: retrieve the challenge flag"
        ],
        "hint1": "Search pages that reflect input are common XSS targets.",
        "hint2": "Try script tags or an image onerror payload."
    },
    {
        "id": "idor",
        "title": "IDOR Lab",
        "description": "Manipulate the object ID in the URL to access another user's record.",
        "difficulty": "Easy",
        "category": "Web Security",
        "skill_area": "Access Control",
        "mitre": "T1190 - Exploit Public-Facing Application",
        "flag": "FLAG{IDOR_DISCOVERED}",
        "points": 15,
        "simulation_steps": [
            "Recon: inspect URL parameters",
            "Probe: identify numeric object references",
            "Exploit: modify the id parameter",
            "Access: open another user's record",
            "Capture: retrieve the challenge flag"
        ],
        "hint1": "Look closely at the id parameter in the URL.",
        "hint2": "Try changing the URL from one record number to another."
    }
]

CAMPAIGNS = [
    {
        "id": "web_kill_chain",
        "title": "Interactive Web Attack Campaign",
        "description": "A guided red-team style exercise chaining recon, SQLi, XSS, IDOR, and objective completion.",
        "level": "Beginner",
        "target": "Cyber Range Web App",
        "framework": "MITRE ATT&CK Guided Campaign",
        "steps": [
            {
                "order": 1,
                "id": "recon",
                "name": "Reconnaissance",
                "type": "task",
                "technique": "T1595 - Active Scanning",
                "instruction": "Review the available labs and identify vulnerable entry points: login form, search page, and id parameter."
            },
            {
                "order": 2,
                "id": "sqli_step",
                "name": "SQL Injection Exploitation",
                "type": "lab",
                "challenge_id": "sqli",
                "technique": "T1190 - Exploit Public-Facing Application",
                "instruction": "Exploit the unsafe login query and recover the flag."
            },
            {
                "order": 3,
                "id": "xss_step",
                "name": "Reflected XSS Exploitation",
                "type": "lab",
                "challenge_id": "xss",
                "technique": "T1059.007 - JavaScript",
                "instruction": "Exploit the reflected search page and recover the flag."
            },
            {
                "order": 4,
                "id": "idor_step",
                "name": "IDOR Exploitation",
                "type": "lab",
                "challenge_id": "idor",
                "technique": "T1190 - Exploit Public-Facing Application",
                "instruction": "Modify the id parameter in the URL and recover the flag."
            },
            {
                "order": 5,
                "id": "objective",
                "name": "Objective Completion",
                "type": "auto",
                "technique": "Training Validation",
                "instruction": "Complete all linked labs to finish the campaign."
            }
        ]
    }
]

IDOR_RECORDS = {
    "1001": {
        "owner": "student",
        "role": "Student",
        "email": "student@lab.local",
        "notes": "Normal learner profile."
    },
    "1002": {
        "owner": "analyst",
        "role": "SOC Analyst",
        "email": "analyst@lab.local",
        "notes": "Internal operations profile."
    },
    "1003": {
        "owner": "admin",
        "role": "Administrator",
        "email": "admin@lab.local",
        "notes": "Sensitive admin record. Flag: FLAG{IDOR_DISCOVERED}"
    }
}

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        score INTEGER DEFAULT 0
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS task_submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        task_name TEXT NOT NULL,
        status TEXT NOT NULL
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS challenge_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        challenge_id TEXT NOT NULL,
        success INTEGER DEFAULT 0,
        submitted_value TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS campaign_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        campaign_id TEXT NOT NULL,
        campaign_title TEXT NOT NULL,
        current_step_order INTEGER DEFAULT 1,
        run_status TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    cursor.execute("PRAGMA table_info(campaign_runs)")
    campaign_run_columns = [row[1] for row in cursor.fetchall()]
    if "current_step_order" not in campaign_run_columns:
        cursor.execute("ALTER TABLE campaign_runs ADD COLUMN current_step_order INTEGER DEFAULT 1")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS campaign_step_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        campaign_id TEXT NOT NULL,
        step_order INTEGER NOT NULL,
        step_id TEXT NOT NULL,
        step_name TEXT NOT NULL,
        technique TEXT NOT NULL,
        step_status TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()

def get_db_connection():
    init_db()
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def get_challenge(challenge_id):
    return next((c for c in CHALLENGES if c["id"] == challenge_id), None)

def get_campaign(campaign_id):
    return next((c for c in CAMPAIGNS if c["id"] == campaign_id), None)

def ensure_user_exists(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
    user = cursor.fetchone()
    if not user:
        cursor.execute("INSERT INTO users (username, score) VALUES (?, ?)", (username, 0))
        conn.commit()
    conn.close()

def get_user_score(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT score FROM users WHERE username = ?", (username,))
    row = cursor.fetchone()
    conn.close()
    return row["score"] if row else 0

def has_completed_task(username, task_name):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT 1 FROM task_submissions
        WHERE username = ? AND task_name = ? AND status = 'completed'
    """, (username, task_name))
    row = cursor.fetchone()
    conn.close()
    return row is not None

def get_completed_titles(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT task_name FROM task_submissions
        WHERE username = ? AND status = 'completed'
    """, (username,))
    rows = cursor.fetchall()
    conn.close()
    return [row["task_name"] for row in rows]

def record_attempt(username, challenge_id, submitted_value, success):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO challenge_attempts (username, challenge_id, success, submitted_value)
        VALUES (?, ?, ?, ?)
    """, (username, challenge_id, 1 if success else 0, submitted_value))
    conn.commit()
    conn.close()

def get_attempt_count(username, challenge_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT COUNT(*) AS total
        FROM challenge_attempts
        WHERE username = ? AND challenge_id = ?
    """, (username, challenge_id))
    row = cursor.fetchone()
    conn.close()
    return row["total"] if row else 0

def get_analytics(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT challenge_id,
               COUNT(*) as attempts,
               SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successes
        FROM challenge_attempts
        WHERE username = ?
        GROUP BY challenge_id
    """, (username,))
    rows = cursor.fetchall()
    conn.close()
    return {
        row["challenge_id"]: {
            "attempts": row["attempts"],
            "successes": row["successes"] or 0
        } for row in rows
    }

def get_hint_for_challenge(username, challenge_id):
    challenge = get_challenge(challenge_id)
    if not challenge:
        return None
    attempts = get_attempt_count(username, challenge_id)
    if attempts >= 4:
        return challenge.get("hint2")
    if attempts >= 2:
        return challenge.get("hint1")
    return None

def get_learning_path(username):
    analytics = get_analytics(username)
    incomplete = []
    for challenge in CHALLENGES:
        completed = has_completed_task(username, challenge["title"])
        attempts = analytics.get(challenge["id"], {}).get("attempts", 0)
        if not completed:
            incomplete.append((attempts, challenge))
    if not incomplete:
        return "All current labs completed. Recommended next step: run the full campaign and review analytics."
    incomplete.sort(key=lambda x: (-x[0], x[1]["difficulty"]))
    target = incomplete[0][1]
    return f"Recommended next lab: {target['title']} ({target['skill_area']}). Focus on {target['mitre']}."

def submit_flag(username, challenge):
    if has_completed_task(username, challenge["title"]):
        return "You already completed this challenge."

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO task_submissions (username, task_name, status)
        VALUES (?, ?, ?)
    """, (username, challenge["title"], "completed"))
    cursor.execute("""
        UPDATE users
        SET score = score + ?
        WHERE username = ?
    """, (challenge["points"], username))
    conn.commit()
    conn.close()
    update_campaign_progress_for_user(username)
    return f"Correct flag. {challenge['points']} points added."

def start_campaign(username, campaign):
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        DELETE FROM campaign_step_progress
        WHERE username = ? AND campaign_id = ?
    """, (username, campaign["id"]))

    cursor.execute("""
        DELETE FROM campaign_runs
        WHERE username = ? AND campaign_id = ?
    """, (username, campaign["id"]))

    cursor.execute("""
        INSERT INTO campaign_runs (username, campaign_id, campaign_title, current_step_order, run_status)
        VALUES (?, ?, ?, ?, ?)
    """, (username, campaign["id"], campaign["title"], 1, "in_progress"))

    for step in campaign["steps"]:
        cursor.execute("""
            INSERT INTO campaign_step_progress
            (username, campaign_id, step_order, step_id, step_name, technique, step_status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            username,
            campaign["id"],
            step["order"],
            step["id"],
            step["name"],
            step["technique"],
            "pending"
        ))

    cursor.execute("""
        UPDATE campaign_step_progress
        SET step_status = 'current'
        WHERE username = ? AND campaign_id = ? AND step_order = 1
    """, (username, campaign["id"]))

    conn.commit()
    conn.close()

def complete_campaign_step(username, campaign_id, step_order):
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        UPDATE campaign_step_progress
        SET step_status = 'completed'
        WHERE username = ? AND campaign_id = ? AND step_order = ?
    """, (username, campaign_id, step_order))

    next_order = step_order + 1
    cursor.execute("""
        SELECT id FROM campaign_step_progress
        WHERE username = ? AND campaign_id = ? AND step_order = ?
    """, (username, campaign_id, next_order))
    next_step = cursor.fetchone()

    if next_step:
        cursor.execute("""
            UPDATE campaign_step_progress
            SET step_status = 'current'
            WHERE username = ? AND campaign_id = ? AND step_order = ?
              AND step_status = 'pending'
        """, (username, campaign_id, next_order))
        cursor.execute("""
            UPDATE campaign_runs
            SET current_step_order = ?, run_status = 'in_progress'
            WHERE username = ? AND campaign_id = ?
        """, (next_order, username, campaign_id))
    else:
        cursor.execute("""
            UPDATE campaign_runs
            SET run_status = 'completed'
            WHERE username = ? AND campaign_id = ?
        """, (username, campaign_id))

    conn.commit()
    conn.close()

def get_campaign_run(username, campaign_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT *
        FROM campaign_runs
        WHERE username = ? AND campaign_id = ?
        ORDER BY id DESC
        LIMIT 1
    """, (username, campaign_id))
    row = cursor.fetchone()
    conn.close()
    return row

def get_campaign_steps(username, campaign_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT *
        FROM campaign_step_progress
        WHERE username = ? AND campaign_id = ?
        ORDER BY step_order ASC
    """, (username, campaign_id))
    rows = cursor.fetchall()
    conn.close()
    return rows

def get_campaign_runs(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT campaign_title, campaign_id, run_status, current_step_order, created_at
        FROM campaign_runs
        WHERE username = ?
        ORDER BY id DESC
    """, (username,))
    rows = cursor.fetchall()
    conn.close()
    return rows

def update_campaign_progress_for_user(username):
    for campaign in CAMPAIGNS:
        run = get_campaign_run(username, campaign["id"])
        if not run or run["run_status"] != "in_progress":
            continue

        steps = get_campaign_steps(username, campaign["id"])
        current_step = next((s for s in steps if s["step_status"] == "current"), None)
        if not current_step:
            continue

        step_order = current_step["step_order"]
        step_definition = next((s for s in campaign["steps"] if s["order"] == step_order), None)
        if not step_definition:
            continue

        if step_definition["type"] == "lab":
            challenge = get_challenge(step_definition["challenge_id"])
            if challenge and has_completed_task(username, challenge["title"]):
                complete_campaign_step(username, campaign["id"], step_order)

        elif step_definition["type"] == "auto":
            required_lab_steps = [s for s in campaign["steps"] if s.get("type") == "lab"]
            all_done = True
            for lab_step in required_lab_steps:
                challenge = get_challenge(lab_step["challenge_id"])
                if not challenge or not has_completed_task(username, challenge["title"]):
                    all_done = False
                    break
            if all_done:
                complete_campaign_step(username, campaign["id"], step_order)

def get_admin_summary():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT u.username,
               u.score,
               COALESCE(t.completed_count, 0) AS completed_count,
               COALESCE(a.attempt_count, 0) AS attempt_count
        FROM users u
        LEFT JOIN (
            SELECT username, COUNT(*) AS completed_count
            FROM task_submissions
            WHERE status = 'completed'
            GROUP BY username
        ) t ON u.username = t.username
        LEFT JOIN (
            SELECT username, COUNT(*) AS attempt_count
            FROM challenge_attempts
            GROUP BY username
        ) a ON u.username = a.username
        ORDER BY u.score DESC, u.username ASC
    """)
    users = cursor.fetchall()

    cursor.execute("""
        SELECT challenge_id,
               COUNT(*) AS total_attempts,
               SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) AS total_successes
        FROM challenge_attempts
        GROUP BY challenge_id
    """)
    challenge_stats = cursor.fetchall()

    cursor.execute("""
        SELECT username, campaign_id, campaign_title, current_step_order, run_status, created_at
        FROM campaign_runs
        ORDER BY id DESC
    """)
    campaign_runs = cursor.fetchall()

    conn.close()
    return users, challenge_stats, campaign_runs

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        if not username:
            flash("Please enter a username.")
            return redirect(url_for("index"))
        ensure_user_exists(username)
        session["username"] = username
        flash(f"Welcome, {username}")
        return redirect(url_for("dashboard"))
    return render_template("index.html")

@app.route("/dashboard")
def dashboard():
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    score = get_user_score(username)
    completed_titles = get_completed_titles(username)
    recommendation = get_learning_path(username)
    return render_template(
        "dashboard.html",
        username=username,
        score=score,
        completed_count=len(completed_titles),
        total_count=len(CHALLENGES),
        challenges=CHALLENGES,
        completed_titles=completed_titles,
        recommendation=recommendation,
        campaigns=CAMPAIGNS
    )

@app.route("/tasks", methods=["GET", "POST"])
def tasks():
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    message = None

    if request.method == "POST":
        challenge_id = request.form.get("challenge_id")
        flag_input = request.form.get("flag", "").strip()
        challenge = get_challenge(challenge_id)

        if challenge:
            success = flag_input == challenge["flag"]
            record_attempt(username, challenge_id, flag_input, success)
            if success:
                message = submit_flag(username, challenge)
            else:
                message = "Incorrect flag. Try again."

    completed_titles = get_completed_titles(username)
    score = get_user_score(username)
    analytics = get_analytics(username)

    return render_template(
        "tasks.html",
        challenges=CHALLENGES,
        completed_titles=completed_titles,
        score=score,
        message=message,
        analytics=analytics
    )

@app.route("/analytics")
def analytics():
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    score = get_user_score(username)
    completed_titles = get_completed_titles(username)
    analytics_map = get_analytics(username)

    challenge_rows = []
    for challenge in CHALLENGES:
        row = analytics_map.get(challenge["id"], {"attempts": 0, "successes": 0})
        challenge_rows.append({
            "title": challenge["title"],
            "skill_area": challenge["skill_area"],
            "mitre": challenge["mitre"],
            "attempts": row["attempts"],
            "successes": row["successes"],
            "completed": challenge["title"] in completed_titles,
            "recommendation": get_hint_for_challenge(username, challenge["id"])
        })

    return render_template(
        "analytics.html",
        username=username,
        score=score,
        challenge_rows=challenge_rows,
        completed_count=len(completed_titles),
        total_count=len(CHALLENGES),
        recommendation=get_learning_path(username)
    )

@app.route("/campaigns")
def campaigns():
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    return render_template(
        "campaigns.html",
        campaigns=CAMPAIGNS,
        runs=get_campaign_runs(username)
    )

@app.route("/campaigns/start/<campaign_id>", methods=["POST"])
def start_campaign_route(campaign_id):
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    campaign = get_campaign(campaign_id)
    if not campaign:
        abort(404)
    start_campaign(username, campaign)
    flash(f"Campaign '{campaign['title']}' started.")
    return redirect(url_for("campaign_detail", campaign_id=campaign_id))

@app.route("/campaigns/advance/<campaign_id>/<int:step_order>", methods=["POST"])
def advance_campaign_step(campaign_id, step_order):
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    run = get_campaign_run(username, campaign_id)
    if not run:
        flash("Start the campaign first.")
        return redirect(url_for("campaign_detail", campaign_id=campaign_id))

    steps = get_campaign_steps(username, campaign_id)
    current_step = next((s for s in steps if s["step_status"] == "current"), None)
    if current_step and current_step["step_order"] == step_order:
        complete_campaign_step(username, campaign_id, step_order)
        flash("Campaign step completed.")
    else:
        flash("That step is not currently active.")
    return redirect(url_for("campaign_detail", campaign_id=campaign_id))

@app.route("/campaigns/<campaign_id>")
def campaign_detail(campaign_id):
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    campaign = get_campaign(campaign_id)
    if not campaign:
        abort(404)

    update_campaign_progress_for_user(username)

    run = get_campaign_run(username, campaign_id)
    steps = get_campaign_steps(username, campaign_id)

    return render_template(
        "campaign_detail.html",
        campaign=campaign,
        run=run,
        steps=steps
    )

@app.route("/simulate/<challenge_id>")
def simulate_attack(challenge_id):
    if "username" not in session:
        return redirect(url_for("index"))
    challenge = get_challenge(challenge_id)
    if not challenge:
        abort(404)
    return render_template("simulate.html", challenge=challenge)

@app.route("/lab/sqli", methods=["GET", "POST"])
def lab_sqli():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    result = None
    flag = None
    query_preview = None
    sql_error = None
    username_input = ""
    password_input = ""

    if request.method == "POST":
        username_input = request.form.get("username", "")
        password_input = request.form.get("password", "")

        query_preview = (
            "SELECT * FROM users WHERE username = '"
            + username_input + "' AND password = '" + password_input + "';"
        )

        success = False

        if "'" in password_input and "' OR '1'='1" not in password_input and '" OR "1"="1' not in password_input:
            sql_error = "SQL syntax error near \"'\" while parsing login query."
            result = "Application error: database query failed."
        elif username_input == "admin" and password_input == "supersecret":
            result = "Valid credentials, but challenge not solved."
        elif username_input == "admin" and (
            "' OR '1'='1" in password_input or
            '" OR "1"="1' in password_input or
            "' OR 1=1--" in password_input
        ):
            result = "Login bypass successful. Admin session granted."
            flag = "FLAG{SQLI_MASTER}"
            success = True
        else:
            result = "Invalid username or password."

        record_attempt(username, "sqli", f"{username_input} | {password_input}", success)

    return render_template(
        "lab_sqli.html",
        result=result,
        flag=flag,
        query_preview=query_preview,
        sql_error=sql_error,
        username_input=username_input,
        password_input=password_input,
        attempts=get_attempt_count(username, "sqli"),
        hint=get_hint_for_challenge(username, "sqli")
    )

@app.route("/lab/xss", methods=["GET"])
def lab_xss():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    query = request.args.get("q", "")
    flag = None
    executed = False

    if query:
        payload_lower = query.lower()
        valid_payloads = [
            "<script>alert(1)</script>",
            "<script>alert('xss')</script>",
            "<img src=x onerror=alert(1)>",
            "<svg onload=alert(1)>"
        ]

        executed = payload_lower in [p.lower() for p in valid_payloads]
        if executed:
            flag = "FLAG{XSS_HUNTER}"

        record_attempt(username, "xss", query, executed)

    return render_template(
        "lab_xss.html",
        query=query,
        executed=executed,
        flag=flag,
        attempts=get_attempt_count(username, "xss"),
        hint=get_hint_for_challenge(username, "xss")
    )

@app.route("/lab/idor", methods=["GET"])
def lab_idor():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    record_id = request.args.get("id", "1001")
    record = IDOR_RECORDS.get(record_id)
    flag = None
    message = None
    success = False

    if record:
        if record_id == "1003":
            flag = "FLAG{IDOR_DISCOVERED}"
            message = "Unauthorized admin record accessed through direct object reference."
            success = True
        else:
            message = f"Viewing record {record_id}."
    else:
        message = "Record not found."

    if request.args.get("id") is not None:
        record_attempt(username, "idor", record_id, success)

    return render_template(
        "lab_idor.html",
        record_id=record_id,
        record=record,
        message=message,
        flag=flag,
        attempts=get_attempt_count(username, "idor"),
        hint=get_hint_for_challenge(username, "idor")
    )

@app.route("/leaderboard")
def leaderboard():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT username, score FROM users ORDER BY score DESC, username ASC")
    users = cursor.fetchall()
    conn.close()
    return render_template("leaderboard.html", users=users)

@app.route("/admin")
def admin():
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]
    if username != "admin":
        flash("Admin dashboard is only available for username 'admin'.")
        return redirect(url_for("dashboard"))

    users, challenge_stats, campaign_runs = get_admin_summary()
    return render_template(
        "admin.html",
        users=users,
        challenge_stats=challenge_stats,
        campaign_runs=campaign_runs
    )

@app.route("/reset-progress")
def reset_progress():
    if "username" not in session:
        return redirect(url_for("index"))
    username = session["username"]

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM task_submissions WHERE username = ?", (username,))
    cursor.execute("DELETE FROM challenge_attempts WHERE username = ?", (username,))
    cursor.execute("DELETE FROM campaign_runs WHERE username = ?", (username,))
    cursor.execute("DELETE FROM campaign_step_progress WHERE username = ?", (username,))
    cursor.execute("UPDATE users SET score = 0 WHERE username = ?", (username,))
    conn.commit()
    conn.close()

    flash("Your progress has been reset.")
    return redirect(url_for("dashboard"))

@app.route("/logout")
def logout():
    session.clear()
    flash("Logged out successfully.")
    return redirect(url_for("index"))

if __name__ == "__main__":
    init_db()
    app.run(debug=True)
EOF

echo "[+] Writing templates/lab_sqli.html ..."
cat > templates/lab_sqli.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>SQL Injection Lab</h1>
    <p>This demo simulates a vulnerable login page that builds SQL queries unsafely.</p>
    <p><strong>Goal:</strong> bypass authentication for <strong>admin</strong>.</p>
    <p><strong>Attempts so far:</strong> {{ attempts }}</p>

    <form method="POST" class="form">
        <input type="text" name="username" placeholder="Username" value="{{ username_input }}" required>
        <input type="text" name="password" placeholder="Password" value="{{ password_input }}" required>
        <button type="submit">Login</button>
    </form>
</div>

<div class="card">
    <h2>Demo Accounts</h2>
    <div class="code-block">
        admin / supersecret<br>
        student / lab123
    </div>
</div>

{% if query_preview %}
<div class="card">
    <h2>Constructed SQL Query</h2>
    <div class="code-block">{{ query_preview }}</div>
</div>
{% endif %}

{% if sql_error %}
<div class="card">
    <h2>Database Error</h2>
    <div class="error-box">{{ sql_error }}</div>
</div>
{% endif %}

{% if result %}
<div class="card">
    <h2>Application Response</h2>
    <p>{{ result }}</p>
</div>
{% endif %}

{% if hint %}
<div class="card">
    <h2>Adaptive Hint</h2>
    <div class="info">{{ hint }}</div>
</div>
{% endif %}

{% if flag %}
<div class="card">
    <h2 class="success">Flag Revealed</h2>
    <p><strong>{{ flag }}</strong></p>
    <a class="btn" href="{{ url_for('tasks') }}">Submit This Flag</a>
</div>
{% endif %}
{% endblock %}
EOF

echo "[+] Writing templates/lab_xss.html ..."
cat > templates/lab_xss.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>Reflected XSS Lab</h1>
    <p>This demo simulates a vulnerable search page that reflects input into HTML without sanitization.</p>
    <p><strong>Goal:</strong> inject a payload into the <code>q</code> URL parameter.</p>
    <p><strong>Attempts so far:</strong> {{ attempts }}</p>

    <form method="GET" class="form">
        <input type="text" name="q" placeholder="Search query" value="{{ query }}" required>
        <button type="submit">Search</button>
    </form>

    <div class="code-block">
        Example URL pattern:<br>
        /lab/xss?q=test
    </div>
</div>

{% if query %}
<div class="card">
    <h2>Search Results for:</h2>
    <div class="unsafe-box">{{ query|safe }}</div>
    <p class="muted">The value above is rendered unsafely into the page.</p>
</div>
{% endif %}

{% if executed %}
<div class="card">
    <h2>Execution Status</h2>
    <p>The reflected payload matched an executable XSS pattern.</p>
</div>
{% endif %}

{% if hint %}
<div class="card">
    <h2>Adaptive Hint</h2>
    <div class="info">{{ hint }}</div>
</div>
{% endif %}

{% if flag %}
<div class="card">
    <h2 class="success">Flag Revealed</h2>
    <p><strong>{{ flag }}</strong></p>
    <a class="btn" href="{{ url_for('tasks') }}">Submit This Flag</a>
</div>
{% endif %}
{% endblock %}
EOF

echo "[+] Writing templates/lab_idor.html ..."
cat > templates/lab_idor.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>IDOR Lab</h1>
    <p>This demo simulates direct object reference via the <code>id</code> URL parameter.</p>
    <p><strong>Goal:</strong> change the URL parameter to access another user's record.</p>
    <p><strong>Attempts so far:</strong> {{ attempts }}</p>

    <form method="GET" class="form">
        <input type="text" name="id" placeholder="Record ID" value="{{ record_id }}" required>
        <button type="submit">Open Record</button>
    </form>

    <div class="code-block">
        Example URLs:<br>
        /lab/idor?id=1001<br>
        /lab/idor?id=1002<br>
        /lab/idor?id=1003
    </div>
</div>

{% if message %}
<div class="card">
    <h2>Record View</h2>
    <p>{{ message }}</p>
    {% if record %}
    <div class="code-block">
        Record ID: {{ record_id }}<br>
        Owner: {{ record.owner }}<br>
        Role: {{ record.role }}<br>
        Email: {{ record.email }}<br>
        Notes: {{ record.notes }}
    </div>
    {% endif %}
</div>
{% endif %}

{% if hint %}
<div class="card">
    <h2>Adaptive Hint</h2>
    <div class="info">{{ hint }}</div>
</div>
{% endif %}

{% if flag %}
<div class="card">
    <h2 class="success">Flag Revealed</h2>
    <p><strong>{{ flag }}</strong></p>
    <a class="btn" href="{{ url_for('tasks') }}">Submit This Flag</a>
</div>
{% endif %}
{% endblock %}
EOF

echo "[+] Writing templates/dashboard.html ..."
cat > templates/dashboard.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="dashboard-grid">
    <div class="card stat-card">
        <h2>Welcome, {{ username }}</h2>
        <p class="stat-value">{{ score }}</p>
        <p class="stat-label">Total Score</p>
    </div>
    <div class="card stat-card">
        <h2>Progress</h2>
        <p class="stat-value">{{ completed_count }}/{{ total_count }}</p>
        <p class="stat-label">Challenges Completed</p>
    </div>
</div>

<div class="card">
    <h2>Recommended Learning Path</h2>
    <p>{{ recommendation }}</p>
    <div class="button-group">
        <a class="btn secondary" href="{{ url_for('tasks') }}">Go to Flag Submission</a>
        <a class="btn secondary" href="{{ url_for('analytics') }}">Open Analytics</a>
        <a class="btn secondary" href="{{ url_for('campaigns') }}">Open Campaigns</a>
        <a class="btn danger" href="{{ url_for('reset_progress') }}">Reset My Progress</a>
    </div>
</div>

<div class="card">
    <h2>Available Labs</h2>
    <div class="challenge-grid">
        {% for challenge in challenges %}
        <div class="challenge-box">
            <h3>{{ challenge.title }}</h3>
            <p>{{ challenge.description }}</p>
            <p><strong>Category:</strong> {{ challenge.category }}</p>
            <p><strong>Difficulty:</strong> {{ challenge.difficulty }}</p>
            <p><strong>Skill Area:</strong> {{ challenge.skill_area }}</p>
            <p><strong>MITRE ATT&CK:</strong> {{ challenge.mitre }}</p>
            <p><strong>Points:</strong> {{ challenge.points }}</p>

            {% if challenge.title in completed_titles %}
            <p class="success">Status: Completed</p>
            {% else %}
            <p class="pending">Status: Not Completed</p>
            {% endif %}

            <div class="button-group">
                {% if challenge.id == 'sqli' %}
                <a class="btn" href="{{ url_for('lab_sqli') }}">Open Lab</a>
                {% elif challenge.id == 'xss' %}
                <a class="btn" href="{{ url_for('lab_xss') }}">Open Lab</a>
                {% elif challenge.id == 'idor' %}
                <a class="btn" href="{{ url_for('lab_idor') }}">Open Lab</a>
                {% endif %}
                <a class="btn secondary" href="{{ url_for('simulate_attack', challenge_id=challenge.id) }}">Simulate Attack</a>
            </div>
        </div>
        {% endfor %}
    </div>
</div>

<div class="card">
    <h2>Interactive Campaigns</h2>
    <div class="challenge-grid">
        {% for campaign in campaigns %}
        <div class="challenge-box">
            <h3>{{ campaign.title }}</h3>
            <p>{{ campaign.description }}</p>
            <p><strong>Framework:</strong> {{ campaign.framework }}</p>
            <p><strong>Level:</strong> {{ campaign.level }}</p>
            <p><strong>Target:</strong> {{ campaign.target }}</p>
            <a class="btn secondary" href="{{ url_for('campaign_detail', campaign_id=campaign.id) }}">Open Campaign</a>
        </div>
        {% endfor %}
    </div>
</div>
{% endblock %}
EOF

echo "[+] Writing templates/base.html ..."
cat > templates/base.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mini Cyber Range</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
    <nav class="navbar">
        <div class="nav-left">
            <a href="{{ url_for('dashboard') }}">Dashboard</a>
            <a href="{{ url_for('tasks') }}">Tasks</a>
            <a href="{{ url_for('analytics') }}">Analytics</a>
            <a href="{{ url_for('campaigns') }}">Campaigns</a>
            <a href="{{ url_for('leaderboard') }}">Leaderboard</a>
            {% if session.get('username') == 'admin' %}
            <a href="{{ url_for('admin') }}">Admin</a>
            {% endif %}
        </div>
        <div class="nav-right">
            {% if session.get('username') %}
                <span class="user-badge">User: {{ session.get('username') }}</span>
                <a href="{{ url_for('logout') }}">Logout</a>
            {% endif %}
        </div>
    </nav>

    <main class="container">
        {% with messages = get_flashed_messages() %}
            {% if messages %}
                {% for msg in messages %}
                    <div class="flash">{{ msg }}</div>
                {% endfor %}
            {% endif %}
        {% endwith %}
        {% block content %}{% endblock %}
    </main>
</body>
</html>
EOF

echo "[+] Writing templates/index.html ..."
cat > templates/index.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="hero-card">
    <h1>Mini Cyber Range Platform</h1>
    <p>Practice labs, interactive campaigns, assessment analytics, and guided learning paths.</p>
    <form method="POST" class="form form-narrow">
        <input type="text" name="username" placeholder="Enter username" required>
        <button type="submit">Login</button>
    </form>
    <p class="muted">Use username <strong>admin</strong> to open the instructor dashboard.</p>
</div>
{% endblock %}
EOF

echo "[+] Writing templates/tasks.html ..."
cat > templates/tasks.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>Flag Submission</h1>
    <p>Your current score: <strong>{{ score }}</strong></p>
    {% if message %}
    <div class="info">{{ message }}</div>
    {% endif %}
</div>

{% for challenge in challenges %}
<div class="card">
    <h2>{{ challenge.title }}</h2>
    <p><strong>Description:</strong> {{ challenge.description }}</p>
    <p><strong>Difficulty:</strong> {{ challenge.difficulty }}</p>
    <p><strong>Category:</strong> {{ challenge.category }}</p>
    <p><strong>Skill Area:</strong> {{ challenge.skill_area }}</p>
    <p><strong>MITRE ATT&CK:</strong> {{ challenge.mitre }}</p>
    <p><strong>Points:</strong> {{ challenge.points }}</p>
    <p><strong>Attempts:</strong> {{ analytics.get(challenge.id, {}).get('attempts', 0) }}</p>

    {% if challenge.title in completed_titles %}
    <p class="success">Completed</p>
    {% else %}
    <form method="POST" class="form">
        <input type="hidden" name="challenge_id" value="{{ challenge.id }}">
        <input type="text" name="flag" placeholder="Enter challenge flag" required>
        <button type="submit">Submit Flag</button>
    </form>
    {% endif %}
</div>
{% endfor %}
{% endblock %}
EOF

echo "[+] Writing templates/analytics.html ..."
cat > templates/analytics.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="dashboard-grid">
    <div class="card stat-card">
        <h2>Score</h2>
        <p class="stat-value">{{ score }}</p>
        <p class="stat-label">Current Score</p>
    </div>
    <div class="card stat-card">
        <h2>Completion</h2>
        <p class="stat-value">{{ completed_count }}/{{ total_count }}</p>
        <p class="stat-label">Finished Labs</p>
    </div>
</div>

<div class="card">
    <h2>Learner Recommendation</h2>
    <p>{{ recommendation }}</p>
</div>

<div class="card">
    <h2>Performance Analytics</h2>
    <table>
        <thead>
            <tr>
                <th>Challenge</th>
                <th>Skill Area</th>
                <th>MITRE ATT&CK</th>
                <th>Attempts</th>
                <th>Successes</th>
                <th>Status</th>
                <th>Adaptive Hint</th>
            </tr>
        </thead>
        <tbody>
            {% for row in challenge_rows %}
            <tr>
                <td>{{ row.title }}</td>
                <td>{{ row.skill_area }}</td>
                <td>{{ row.mitre }}</td>
                <td>{{ row.attempts }}</td>
                <td>{{ row.successes }}</td>
                <td>
                    {% if row.completed %}
                    <span class="success">Completed</span>
                    {% else %}
                    <span class="pending">In Progress</span>
                    {% endif %}
                </td>
                <td>{{ row.recommendation or 'No hint yet' }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
EOF

echo "[+] Writing templates/campaigns.html ..."
cat > templates/campaigns.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>Interactive Campaigns</h1>
    <p>Campaigns guide the learner through multiple stages and automatically progress when linked labs are completed.</p>
</div>

<div class="challenge-grid">
    {% for campaign in campaigns %}
    <div class="challenge-box">
        <h3>{{ campaign.title }}</h3>
        <p>{{ campaign.description }}</p>
        <p><strong>Framework:</strong> {{ campaign.framework }}</p>
        <p><strong>Level:</strong> {{ campaign.level }}</p>
        <p><strong>Target:</strong> {{ campaign.target }}</p>
        <p><strong>Phases:</strong> {{ campaign.steps|length }}</p>
        <a class="btn secondary" href="{{ url_for('campaign_detail', campaign_id=campaign.id) }}">Open Campaign</a>
    </div>
    {% endfor %}
</div>

<div class="card">
    <h2>Recent Runs</h2>
    {% if runs %}
    <table>
        <thead>
            <tr>
                <th>Campaign</th>
                <th>Status</th>
                <th>Current Step</th>
                <th>Started At</th>
            </tr>
        </thead>
        <tbody>
            {% for run in runs %}
            <tr>
                <td>{{ run.campaign_title }}</td>
                <td>{{ run.run_status }}</td>
                <td>{{ run.current_step_order }}</td>
                <td>{{ run.created_at }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
    {% else %}
    <p>No campaign runs yet.</p>
    {% endif %}
</div>
{% endblock %}
EOF

echo "[+] Writing templates/campaign_detail.html ..."
cat > templates/campaign_detail.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>{{ campaign.title }}</h1>
    <p>{{ campaign.description }}</p>
    <p><strong>Framework:</strong> {{ campaign.framework }}</p>
    <p><strong>Level:</strong> {{ campaign.level }}</p>
    <p><strong>Target:</strong> {{ campaign.target }}</p>

    {% if run %}
        <p><strong>Status:</strong> {{ run.run_status }}</p>
        <p><strong>Current Step:</strong> {{ run.current_step_order }}</p>
    {% else %}
        <form method="POST" action="{{ url_for('start_campaign_route', campaign_id=campaign.id) }}">
            <button type="submit">Start Campaign</button>
        </form>
    {% endif %}
</div>

<div class="card">
    <h2>Campaign Steps</h2>
    {% if steps %}
        <ol class="step-list">
            {% for step in steps %}
            <li class="step-item">
                <strong>{{ step.step_order }}. {{ step.step_name }}</strong><br>
                <span><strong>Technique:</strong> {{ step.technique }}</span><br>
                <span><strong>Status:</strong>
                    {% if step.step_status == 'completed' %}
                        <span class="success">Completed</span>
                    {% elif step.step_status == 'current' %}
                        <span class="pending">Current</span>
                    {% else %}
                        Pending
                    {% endif %}
                </span><br>

                {% set step_def = campaign.steps[step.step_order - 1] %}
                <p>{{ step_def.instruction }}</p>

                {% if step.step_status == 'current' and step_def.type == 'task' %}
                    <form method="POST" action="{{ url_for('advance_campaign_step', campaign_id=campaign.id, step_order=step.step_order) }}">
                        <button type="submit">Mark Recon Step Complete</button>
                    </form>
                {% elif step.step_status == 'current' and step_def.type == 'lab' %}
                    {% if step_def.challenge_id == 'sqli' %}
                        <a class="btn" href="{{ url_for('lab_sqli') }}">Open SQLi Lab</a>
                    {% elif step_def.challenge_id == 'xss' %}
                        <a class="btn" href="{{ url_for('lab_xss') }}">Open XSS Lab</a>
                    {% elif step_def.challenge_id == 'idor' %}
                        <a class="btn" href="{{ url_for('lab_idor') }}">Open IDOR Lab</a>
                    {% endif %}
                {% elif step.step_status == 'current' and step_def.type == 'auto' %}
                    <p>Complete all linked labs to finish this step automatically.</p>
                {% endif %}
            </li>
            {% endfor %}
        </ol>
    {% else %}
        <p>Start the campaign to generate interactive steps.</p>
    {% endif %}
</div>
{% endblock %}
EOF

echo "[+] Writing templates/simulate.html ..."
cat > templates/simulate.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>{{ challenge.title }} - Attack Simulation</h1>
    <p>{{ challenge.description }}</p>
    <p><strong>Skill Area:</strong> {{ challenge.skill_area }}</p>
    <p><strong>MITRE ATT&CK:</strong> {{ challenge.mitre }}</p>
    <p><strong>Difficulty:</strong> {{ challenge.difficulty }}</p>
</div>

<div class="card">
    <h2>Simulated Attack Flow</h2>
    <ol class="step-list">
        {% for step in challenge.simulation_steps %}
        <li>{{ step }}</li>
        {% endfor %}
    </ol>
</div>
{% endblock %}
EOF

echo "[+] Writing templates/leaderboard.html ..."
cat > templates/leaderboard.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>Leaderboard</h1>
    <table>
        <thead>
            <tr>
                <th>Rank</th>
                <th>Username</th>
                <th>Score</th>
            </tr>
        </thead>
        <tbody>
            {% for user in users %}
            <tr>
                <td>{{ loop.index }}</td>
                <td>{{ user.username }}</td>
                <td>{{ user.score }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
EOF

echo "[+] Writing templates/admin.html ..."
cat > templates/admin.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>Instructor / Admin Dashboard</h1>
    <p>Overview of learner performance, attempts, and campaign progress.</p>
</div>

<div class="card">
    <h2>User Summary</h2>
    <table>
        <thead>
            <tr>
                <th>User</th>
                <th>Score</th>
                <th>Completed Labs</th>
                <th>Total Attempts</th>
            </tr>
        </thead>
        <tbody>
            {% for user in users %}
            <tr>
                <td>{{ user.username }}</td>
                <td>{{ user.score }}</td>
                <td>{{ user.completed_count }}</td>
                <td>{{ user.attempt_count }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
</div>

<div class="card">
    <h2>Challenge Overview</h2>
    <table>
        <thead>
            <tr>
                <th>Challenge ID</th>
                <th>Total Attempts</th>
                <th>Total Successes</th>
            </tr>
        </thead>
        <tbody>
            {% for stat in challenge_stats %}
            <tr>
                <td>{{ stat.challenge_id }}</td>
                <td>{{ stat.total_attempts }}</td>
                <td>{{ stat.total_successes or 0 }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
</div>

<div class="card">
    <h2>Campaign Runs</h2>
    <table>
        <thead>
            <tr>
                <th>User</th>
                <th>Campaign</th>
                <th>Status</th>
                <th>Current Step</th>
                <th>Created At</th>
            </tr>
        </thead>
        <tbody>
            {% for run in campaign_runs %}
            <tr>
                <td>{{ run.username }}</td>
                <td>{{ run.campaign_title }}</td>
                <td>{{ run.run_status }}</td>
                <td>{{ run.current_step_order }}</td>
                <td>{{ run.created_at }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
EOF

echo "[+] Writing static/style.css ..."
cat > static/style.css <<'EOF'
body {
    font-family: Arial, sans-serif;
    background: #0b1220;
    color: #e5e7eb;
    margin: 0;
    padding: 0;
}

.navbar {
    background: #111827;
    padding: 16px 28px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #1f2937;
}

.navbar a {
    color: #e5e7eb;
    text-decoration: none;
    margin-right: 16px;
}

.navbar a:hover {
    color: #93c5fd;
}

.user-badge {
    margin-right: 14px;
    color: #cbd5e1;
}

.container {
    max-width: 1100px;
    margin: 30px auto;
    padding: 20px;
}

.hero-card,
.card {
    background: #111827;
    border: 1px solid #1f2937;
    padding: 24px;
    margin-bottom: 20px;
    border-radius: 14px;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.25);
}

.hero-card h1 {
    margin-top: 0;
    font-size: 34px;
}

.dashboard-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 20px;
    margin-bottom: 20px;
}

.stat-card {
    text-align: center;
}

.stat-value {
    font-size: 42px;
    font-weight: bold;
    margin: 10px 0 6px;
}

.stat-label, .muted {
    color: #94a3b8;
}

.challenge-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 18px;
}

.challenge-box, .step-item {
    background: #0f172a;
    border: 1px solid #243041;
    border-radius: 12px;
    padding: 18px;
}

.form {
    display: flex;
    flex-direction: column;
    gap: 12px;
}

.form-narrow {
    max-width: 420px;
}

input[type="text"] {
    padding: 12px;
    border: 1px solid #334155;
    background: #0f172a;
    color: #e5e7eb;
    border-radius: 8px;
    font-size: 15px;
}

button, .btn {
    display: inline-block;
    background: #2563eb;
    color: white;
    padding: 10px 16px;
    border: none;
    border-radius: 8px;
    text-decoration: none;
    cursor: pointer;
    margin-right: 10px;
}

button:hover, .btn:hover {
    background: #1d4ed8;
}

.secondary {
    background: #475569;
}

.secondary:hover {
    background: #334155;
}

.danger {
    background: #b91c1c;
}

.danger:hover {
    background: #991b1b;
}

.flash, .info {
    background: #1e293b;
    border: 1px solid #334155;
    padding: 12px;
    border-radius: 8px;
    margin-bottom: 15px;
    word-break: break-word;
}

.success {
    color: #22c55e;
    font-weight: bold;
}

.pending {
    color: #fbbf24;
    font-weight: bold;
}

.code-block,
.unsafe-box,
.error-box {
    background: #0f172a;
    border: 1px solid #334155;
    padding: 14px;
    border-radius: 10px;
    overflow-x: auto;
    word-break: break-word;
}

.error-box {
    color: #fca5a5;
    border-color: #7f1d1d;
}

.step-list li {
    margin-bottom: 14px;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
}

table th, table td {
    border: 1px solid #334155;
    padding: 12px;
    text-align: left;
}

table th {
    background: #1e293b;
}

.button-group {
    margin-top: 15px;
}

@media (max-width: 800px) {
    .dashboard-grid,
    .challenge-grid {
        grid-template-columns: 1fr;
    }

    .navbar {
        flex-direction: column;
        align-items: flex-start;
        gap: 10px;
    }
}
EOF

echo ""
echo "======================================"
echo " Realistic lab upgrade applied"
echo "======================================"
echo "Now restart:"
echo "python3 app.py"
echo ""
echo "Test examples:"
echo "SQLi: username=admin, password='"
echo "SQLi bypass: username=admin, password=' OR '1'='1"
echo "XSS: /lab/xss?q=<script>alert(1)</script>"
echo "IDOR: /lab/idor?id=1003"
