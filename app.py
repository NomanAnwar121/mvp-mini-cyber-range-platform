import os
import sqlite3
from datetime import datetime
from flask import Flask, render_template, request, redirect, session, url_for, flash

app = Flask(__name__)
app.secret_key = "mini-cyber-range-secret-key"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_NAME = os.path.join(BASE_DIR, "cyber_range.db")

CHALLENGES = [
    {
        "id": "sqli",
        "title": "SQL Injection Lab",
        "description": "Bypass the login form using SQL injection and recover the hidden flag.",
        "difficulty": "Easy",
        "category": "Web Security",
        "skill_area": "Injection Attacks",
        "mitre": "T1190 - Exploit Public-Facing Application",
        "flag": "FLAG{SQLI_MASTER}",
        "points": 10,
        "simulation_steps": [
            "Recon: identify login form parameters",
            "Probe: test quote characters in the login form",
            "Exploit: inject authentication bypass payload",
            "Access: gain unauthorized admin access",
            "Capture: recover the challenge flag"
        ]
    },
    {
        "id": "xss",
        "title": "Reflected XSS Lab",
        "description": "Inject JavaScript into an unsafe search page and reveal the hidden flag.",
        "difficulty": "Easy",
        "category": "Web Security",
        "skill_area": "Client-Side Attacks",
        "mitre": "T1059.007 - JavaScript",
        "flag": "FLAG{XSS_HUNTER}",
        "points": 10,
        "simulation_steps": [
            "Recon: inspect reflected query parameter",
            "Probe: test harmless HTML injection",
            "Exploit: inject script payload through URL query",
            "Execution: trigger browser-side script handling",
            "Capture: reveal the challenge flag"
        ]
    },
    {
        "id": "stored_xss",
        "title": "Stored XSS Lab",
        "description": "Inject a payload into a comment system that is rendered unsafely.",
        "difficulty": "Easy",
        "category": "Web Security",
        "skill_area": "Client-Side Attacks",
        "mitre": "T1059.007 - JavaScript",
        "flag": "FLAG{STORED_XSS_FOUND}",
        "points": 10,
        "simulation_steps": [
            "Recon: inspect comment submission form",
            "Probe: submit harmless input",
            "Exploit: store script payload in comment field",
            "Execution: payload is rendered back unsafely",
            "Capture: recover the hidden flag"
        ]
    },
    {
        "id": "idor",
        "title": "IDOR Lab",
        "description": "Access another user's record by changing the object identifier directly in the URL.",
        "difficulty": "Easy",
        "category": "Web Security",
        "skill_area": "Access Control",
        "mitre": "T1190 - Exploit Public-Facing Application",
        "flag": "FLAG{IDOR_DISCOVERED}",
        "points": 10,
        "simulation_steps": [
            "Recon: inspect available object identifiers",
            "Observe: identify predictable numeric IDs",
            "Manipulate: change the object ID in the URL",
            "Access: retrieve unauthorized record data",
            "Capture: recover the hidden flag"
        ]
    }
]

CAMPAIGNS = [
    {
        "id": "web_attack_chain",
        "title": "Web Attack Campaign",
        "description": "A guided red team exercise simulating reconnaissance, exploitation, and flag capture on a vulnerable web application.",
        "level": "Beginner",
        "target": "Training Web App",
        "framework": "MITRE ATT&CK / Atomic-style Simulation",
        "steps": [
            {
                "name": "Reconnaissance",
                "technique": "T1595 - Active Scanning",
                "atomic_test": "Inspect login form and URL parameters",
                "description": "Discover weak inputs and predictable identifiers."
            },
            {
                "name": "Initial Access",
                "technique": "T1190 - Exploit Public-Facing Application",
                "atomic_test": "Attempt SQL injection against login flow",
                "description": "Simulate an authentication bypass."
            },
            {
                "name": "Execution",
                "technique": "T1059.007 - JavaScript",
                "atomic_test": "Inject reflected or stored XSS payload",
                "description": "Simulate client-side script execution."
            },
            {
                "name": "Object Access Abuse",
                "technique": "Application Logic Abuse",
                "atomic_test": "Change object IDs in URL to access unauthorized data",
                "description": "Simulate IDOR-based data access."
            },
            {
                "name": "Objective",
                "technique": "CTF Objective",
                "atomic_test": "Capture challenge flags and submit them",
                "description": "Validate learner performance."
            }
        ]
    }
]

IDOR_RECORDS = [
    {"id": 1001, "owner": "student", "name": "Student Demo Record", "email": "student@demo.local", "notes": "Normal user-owned data"},
    {"id": 1002, "owner": "student", "name": "Student Billing Record", "email": "student.billing@demo.local", "notes": "Another normal object"},
    {"id": 1003, "owner": "analyst", "name": "Analyst Record", "email": "analyst@demo.local", "notes": "Belongs to another user"},
    {"id": 1004, "owner": "admin", "name": "Admin Restricted Record", "email": "admin@demo.local", "notes": "Confidential object | FLAG{IDOR_DISCOVERED}"},
]

DEFAULT_COMMENTS = [
    {"author": "alice", "content": "Great training platform."},
    {"author": "bob", "content": "The web security labs are helpful."}
]

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
        run_status TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS campaign_run_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        campaign_id TEXT NOT NULL,
        step_name TEXT NOT NULL,
        technique TEXT NOT NULL,
        step_status TEXT NOT NULL,
        log_message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS stored_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        author TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()

def seed_comments():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM stored_comments")
    count = cursor.fetchone()[0]

    if count == 0:
        for row in DEFAULT_COMMENTS:
            cursor.execute("""
                INSERT INTO stored_comments (username, author, content)
                VALUES (?, ?, ?)
            """, ("system", row["author"], row["content"]))
        conn.commit()

    conn.close()

def get_db_connection():
    init_db()
    seed_comments()
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

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

def get_skill_recommendation(username):
    analytics = get_analytics(username)
    weakest = None
    weakest_attempts = -1

    for challenge in CHALLENGES:
        attempts = analytics.get(challenge["id"], {}).get("attempts", 0)
        completed = has_completed_task(username, challenge["title"])
        if not completed and attempts > weakest_attempts:
            weakest_attempts = attempts
            weakest = challenge

    if weakest:
        return f"Recommended focus: {weakest['skill_area']} through {weakest['title']}."
    return "Good progress. Try completing all available labs."

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

    return f"Correct flag. {challenge['points']} points added."

def run_campaign(username, campaign):
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO campaign_runs (username, campaign_id, campaign_title, run_status)
        VALUES (?, ?, ?, ?)
    """, (username, campaign["id"], campaign["title"], "completed"))

    for index, step in enumerate(campaign["steps"], start=1):
        log_message = (
            f"[{datetime.now().strftime('%H:%M:%S')}] "
            f"Step {index}: {step['name']} executed using {step['technique']} | "
            f"Action: {step['atomic_test']}"
        )

        cursor.execute("""
            INSERT INTO campaign_run_steps (
                username, campaign_id, step_name, technique, step_status, log_message
            )
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            username,
            campaign["id"],
            step["name"],
            step["technique"],
            "completed",
            log_message
        ))

    conn.commit()
    conn.close()

def get_campaign_runs(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT campaign_title, campaign_id, run_status, created_at
        FROM campaign_runs
        WHERE username = ?
        ORDER BY id DESC
    """, (username,))
    rows = cursor.fetchall()
    conn.close()
    return rows

def get_campaign_logs(username, campaign_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT step_name, technique, step_status, log_message, created_at
        FROM campaign_run_steps
        WHERE username = ? AND campaign_id = ?
        ORDER BY id ASC
    """, (username, campaign_id))
    rows = cursor.fetchall()
    conn.close()
    return rows

def get_record_by_id(record_id):
    for record in IDOR_RECORDS:
        if record["id"] == record_id:
            return record
    return None

def get_user_records(username):
    return [r for r in IDOR_RECORDS if r["owner"] == username]

def get_all_comments():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, author, content, created_at
        FROM stored_comments
        ORDER BY id DESC
    """)
    rows = cursor.fetchall()
    conn.close()
    return rows

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

    return render_template(
        "dashboard.html",
        username=username,
        score=score,
        completed_count=len(completed_titles),
        total_count=len(CHALLENGES),
        challenges=CHALLENGES,
        completed_titles=completed_titles,
        recommendation=get_skill_recommendation(username),
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

        challenge = next((c for c in CHALLENGES if c["id"] == challenge_id), None)
        if challenge:
            success = flag_input == challenge["flag"]
            record_attempt(username, challenge_id, flag_input, success)

            if success:
                message = submit_flag(username, challenge)
            else:
                message = "Incorrect flag. Try again."

    return render_template(
        "tasks.html",
        challenges=CHALLENGES,
        completed_titles=get_completed_titles(username),
        score=get_user_score(username),
        message=message,
        analytics=get_analytics(username)
    )

@app.route("/analytics")
def analytics():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    completed_titles = get_completed_titles(username)
    analytics_data = get_analytics(username)

    challenge_rows = []
    for challenge in CHALLENGES:
        row = analytics_data.get(challenge["id"], {"attempts": 0, "successes": 0})
        challenge_rows.append({
            "title": challenge["title"],
            "skill_area": challenge["skill_area"],
            "mitre": challenge["mitre"],
            "attempts": row["attempts"],
            "successes": row["successes"],
            "completed": challenge["title"] in completed_titles
        })

    return render_template(
        "analytics.html",
        username=username,
        score=get_user_score(username),
        challenge_rows=challenge_rows,
        completed_count=len(completed_titles),
        total_count=len(CHALLENGES),
        recommendation=get_skill_recommendation(username)
    )

@app.route("/campaigns")
def campaigns():
    if "username" not in session:
        return redirect(url_for("index"))

    return render_template(
        "campaigns.html",
        campaigns=CAMPAIGNS,
        runs=get_campaign_runs(session["username"])
    )

@app.route("/campaigns/run/<campaign_id>", methods=["POST"])
def run_campaign_route(campaign_id):
    if "username" not in session:
        return redirect(url_for("index"))

    campaign = next((c for c in CAMPAIGNS if c["id"] == campaign_id), None)
    if not campaign:
        flash("Campaign not found.")
        return redirect(url_for("campaigns"))

    run_campaign(session["username"], campaign)
    flash(f"Campaign '{campaign['title']}' executed successfully.")
    return redirect(url_for("campaign_detail", campaign_id=campaign_id))

@app.route("/campaigns/<campaign_id>")
def campaign_detail(campaign_id):
    if "username" not in session:
        return redirect(url_for("index"))

    campaign = next((c for c in CAMPAIGNS if c["id"] == campaign_id), None)
    if not campaign:
        flash("Campaign not found.")
        return redirect(url_for("campaigns"))

    return render_template(
        "campaign_detail.html",
        campaign=campaign,
        logs=get_campaign_logs(session["username"], campaign_id)
    )

@app.route("/simulate/<challenge_id>")
def simulate_attack(challenge_id):
    if "username" not in session:
        return redirect(url_for("index"))

    challenge = next((c for c in CHALLENGES if c["id"] == challenge_id), None)
    if not challenge:
        flash("Challenge not found.")
        return redirect(url_for("dashboard"))

    return render_template("simulate.html", challenge=challenge)

@app.route("/lab/sqli", methods=["GET", "POST"])
def lab_sqli():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    result = None
    flag = None
    query_preview = None
    username_input = ""
    password_input = ""
    attempts = get_attempt_count(username, "sqli")
    hint = None

    if request.method == "POST":
        username_input = request.form.get("username", "")
        password_input = request.form.get("password", "")

        query_preview = (
            "SELECT * FROM users WHERE username = '"
            + username_input +
            "' AND password = '"
            + password_input + "'"
        )

        success = False
        if username_input == "admin" and password_input == "supersecret":
            result = "Valid credentials, but no challenge solved yet."
        elif username_input == "admin" and ("' OR '1'='1" in password_input or '" OR "1"="1' in password_input):
            result = "Login bypass successful. You exploited the vulnerable query."
            flag = "FLAG{SQLI_MASTER}"
            success = True
        else:
            result = "Login failed."

        record_attempt(username, "sqli", f"{username_input}|{password_input}", success)
        attempts = get_attempt_count(username, "sqli")

        if not success and attempts >= 2:
            hint = "Automation hint: try a classic authentication bypass payload in the password field."

    return render_template(
        "lab_sqli.html",
        result=result,
        flag=flag,
        query_preview=query_preview,
        username_input=username_input,
        password_input=password_input,
        attempts=attempts,
        hint=hint
    )

@app.route("/lab/xss")
def lab_xss():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    query = request.args.get("q", "welcome")
    executed = False
    flag = None
    hint = None
    attempts = get_attempt_count(username, "xss")

    if query:
        payload_lower = query.lower()
        success = "<script>" in payload_lower and "alert(1)" in payload_lower

        if success:
            executed = True
            flag = "FLAG{XSS_HUNTER}"

        record_attempt(username, "xss", query, success)
        attempts = get_attempt_count(username, "xss")

        if not success and attempts >= 2:
            hint = "Automation hint: use the q parameter with a simple reflected script payload."

    example_url = "/lab/xss?q=welcome"

    return render_template(
        "lab_xss.html",
        query=query,
        executed=executed,
        flag=flag,
        attempts=attempts,
        hint=hint,
        example_url=example_url
    )

@app.route("/lab/stored-xss", methods=["GET", "POST"])
def lab_stored_xss():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    attempts = get_attempt_count(username, "stored_xss")
    hint = None
    flag = None

    if request.method == "POST":
        author = request.form.get("author", "").strip() or username
        content = request.form.get("content", "").strip()

        success = "<script>" in content.lower() and "alert(1)" in content.lower()

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO stored_comments (username, author, content)
            VALUES (?, ?, ?)
        """, (username, author, content))
        conn.commit()
        conn.close()

        record_attempt(username, "stored_xss", content, success)
        attempts = get_attempt_count(username, "stored_xss")

        if success:
            flag = "FLAG{STORED_XSS_FOUND}"
        elif attempts >= 2:
            hint = "Automation hint: try storing a basic script payload in the comment."

        flash("Comment submitted successfully.")
        return render_template(
            "lab_stored_xss.html",
            comments=get_all_comments(),
            attempts=attempts,
            hint=hint,
            flag=flag
        )

    return render_template(
        "lab_stored_xss.html",
        comments=get_all_comments(),
        attempts=attempts,
        hint=hint,
        flag=flag
    )

@app.route("/lab/idor")
def lab_idor():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    record_id = request.args.get("id", type=int, default=1001)
    attempts = get_attempt_count(username, "idor")
    hint = None
    record = get_record_by_id(record_id)
    unauthorized_access = False
    flag = None

    user_records = get_user_records(username)

    if record:
        unauthorized_access = record["owner"] != username
        success = unauthorized_access and record["id"] == 1004

        record_attempt(username, "idor", f"id={record_id}", success)
        attempts = get_attempt_count(username, "idor")

        if success:
            flag = "FLAG{IDOR_DISCOVERED}"
        elif attempts >= 2 and not unauthorized_access:
            hint = "Automation hint: try changing the id value in the URL to another nearby number."
        elif attempts >= 2 and unauthorized_access and not success:
            hint = "Automation hint: you found another user's object. Keep testing nearby IDs."

    example_url = "/lab/idor?id=1001"

    return render_template(
        "lab_idor.html",
        record=record,
        current_id=record_id,
        unauthorized_access=unauthorized_access,
        flag=flag,
        attempts=attempts,
        hint=hint,
        example_url=example_url,
        user_records=user_records
    )

@app.route("/leaderboard")
def leaderboard():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT username, score FROM users ORDER BY score DESC, username ASC")
    users = cursor.fetchall()
    conn.close()

    return render_template("leaderboard.html", users=users)

@app.route("/logout")
def logout():
    session.clear()
    flash("Logged out successfully.")
    return redirect(url_for("index"))

if __name__ == "__main__":
    init_db()
    seed_comments()
    app.run(debug=True)
