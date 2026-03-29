#!/bin/bash

set -e

echo "======================================"
echo " Safe Upgrade Step 1"
echo " Attack Simulation + Analytics + Training Automation"
echo "======================================"

mkdir -p templates
mkdir -p static

echo "[+] Writing app.py ..."
cat > app.py <<'EOF'
import os
import sqlite3
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
            "Probe: test single quote to detect broken query behavior",
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
            "Recon: inspect reflected input in search page",
            "Probe: test harmless HTML injection",
            "Exploit: inject script payload",
            "Execution: trigger browser-side script handling",
            "Capture: reveal the challenge flag"
        ]
    }
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

    conn.commit()
    conn.close()

def get_db_connection():
    init_db()
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def ensure_user_exists(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
    user = cursor.fetchone()

    if not user:
        cursor.execute(
            "INSERT INTO users (username, score) VALUES (?, ?)",
            (username, 0)
        )
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

    stats = {row["challenge_id"]: {"attempts": row["attempts"], "successes": row["successes"] or 0} for row in rows}
    return stats

def get_skill_recommendation(username):
    analytics = get_analytics(username)

    weakest = None
    weakest_attempts = -1

    for challenge in CHALLENGES:
        cid = challenge["id"]
        attempts = analytics.get(cid, {}).get("attempts", 0)
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
    completed_count = len(completed_titles)
    total_count = len(CHALLENGES)
    recommendation = get_skill_recommendation(username)

    return render_template(
        "dashboard.html",
        username=username,
        score=score,
        completed_count=completed_count,
        total_count=total_count,
        challenges=CHALLENGES,
        completed_titles=completed_titles,
        recommendation=recommendation
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
    analytics = get_analytics(username)

    challenge_rows = []
    for challenge in CHALLENGES:
        row = analytics.get(challenge["id"], {"attempts": 0, "successes": 0})
        challenge_rows.append({
            "title": challenge["title"],
            "skill_area": challenge["skill_area"],
            "mitre": challenge["mitre"],
            "attempts": row["attempts"],
            "successes": row["successes"],
            "completed": challenge["title"] in completed_titles
        })

    recommendation = get_skill_recommendation(username)

    return render_template(
        "analytics.html",
        username=username,
        score=score,
        challenge_rows=challenge_rows,
        completed_count=len(completed_titles),
        total_count=len(CHALLENGES),
        recommendation=recommendation
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
            "SELECT * FROM lab_users WHERE username = '"
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

        record_attempt(username, "sqli", f"{username_input} | {password_input}", success)
        attempts = get_attempt_count(username, "sqli")

        if not success and attempts >= 2:
            hint = "Automation hint: use a classic authentication bypass payload in the password field."

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

@app.route("/lab/xss", methods=["GET", "POST"])
def lab_xss():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]
    query = ""
    flag = None
    executed = False
    attempts = get_attempt_count(username, "xss")
    hint = None

    if request.method == "POST":
        query = request.form.get("query", "")
        payload_lower = query.lower()

        if "<script>" in payload_lower and "alert(1)" in payload_lower:
            executed = True
            flag = "FLAG{XSS_HUNTER}"

        record_attempt(username, "xss", query, executed)
        attempts = get_attempt_count(username, "xss")

        if not executed and attempts >= 2:
            hint = "Automation hint: test a basic reflected script payload."

    return render_template(
        "lab_xss.html",
        query=query,
        executed=executed,
        flag=flag,
        attempts=attempts,
        hint=hint
    )

@app.route("/leaderboard")
def leaderboard():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT username, score FROM users ORDER BY score DESC, username ASC")
    users = cursor.fetchall()
    conn.close()

    return render_template("leaderboard.html", users=users)

@app.route("/reset-progress")
def reset_progress():
    if "username" not in session:
        return redirect(url_for("index"))

    username = session["username"]

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM task_submissions WHERE username = ?", (username,))
    cursor.execute("DELETE FROM challenge_attempts WHERE username = ?", (username,))
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
            <a href="{{ url_for('leaderboard') }}">Leaderboard</a>
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
    <p>Practice attack simulation, skills assessment, and training automation through custom cybersecurity labs.</p>

    <form method="POST" class="form form-narrow">
        <input type="text" name="username" placeholder="Enter username" required>
        <button type="submit">Login</button>
    </form>
</div>
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
    <h2>Training Recommendation</h2>
    <p>{{ recommendation }}</p>
    <div class="button-group">
        <a class="btn secondary" href="{{ url_for('tasks') }}">Go to Flag Submission</a>
        <a class="btn secondary" href="{{ url_for('analytics') }}">Open Analytics</a>
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
                {% endif %}
                <a class="btn secondary" href="{{ url_for('simulate_attack', challenge_id=challenge.id) }}">Simulate Attack</a>
            </div>
        </div>
        {% endfor %}
    </div>
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
            </tr>
            {% endfor %}
        </tbody>
    </table>
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

<div class="card">
    <h2>Educational Outcome</h2>
    <p>This simulation helps the learner understand the offensive sequence before performing the hands-on lab.</p>
    <div class="button-group">
        {% if challenge.id == 'sqli' %}
            <a class="btn" href="{{ url_for('lab_sqli') }}">Open SQLi Lab</a>
        {% elif challenge.id == 'xss' %}
            <a class="btn" href="{{ url_for('lab_xss') }}">Open XSS Lab</a>
        {% endif %}
        <a class="btn secondary" href="{{ url_for('tasks') }}">Go to Tasks</a>
    </div>
</div>
{% endblock %}
EOF

echo "[+] Writing templates/lab_sqli.html ..."
cat > templates/lab_sqli.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="card">
    <h1>SQL Injection Lab</h1>
    <p>This lab simulates an insecure login form vulnerable to SQL injection.</p>
    <p><strong>Goal:</strong> bypass authentication for the <strong>admin</strong> account.</p>
    <p><strong>Attempts so far:</strong> {{ attempts }}</p>

    <form method="POST" class="form">
        <input type="text" name="username" placeholder="Username" value="{{ username_input }}" required>
        <input type="text" name="password" placeholder="Password" value="{{ password_input }}" required>
        <button type="submit">Attempt Login</button>
    </form>
</div>

{% if query_preview %}
<div class="card">
    <h2>Unsafe Query Preview</h2>
    <div class="code-block">{{ query_preview }}</div>
</div>
{% endif %}

{% if result %}
<div class="card">
    <h2>Result</h2>
    <p>{{ result }}</p>
</div>
{% endif %}

{% if hint %}
<div class="card">
    <h2>Automation Hint</h2>
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
    <p>This lab simulates an unsafe search page that reflects user input without proper sanitization.</p>
    <p><strong>Goal:</strong> inject a JavaScript payload that would trigger script execution.</p>
    <p><strong>Attempts so far:</strong> {{ attempts }}</p>

    <form method="POST" class="form">
        <input type="text" name="query" placeholder="Search term" value="{{ query }}" required>
        <button type="submit">Search</button>
    </form>
</div>

{% if query %}
<div class="card">
    <h2>Unsafe Reflection Preview</h2>
    <div class="unsafe-box">{{ query|safe }}</div>
</div>
{% endif %}

{% if executed %}
<div class="card">
    <h2>Execution Status</h2>
    <p>The platform detected a successful reflected XSS-style payload.</p>
</div>
{% endif %}

{% if hint %}
<div class="card">
    <h2>Automation Hint</h2>
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

.stat-label {
    color: #94a3b8;
}

.challenge-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 18px;
}

.challenge-box {
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
.unsafe-box {
    background: #0f172a;
    border: 1px solid #334155;
    padding: 14px;
    border-radius: 10px;
    overflow-x: auto;
    word-break: break-word;
}

.step-list li {
    margin-bottom: 10px;
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
echo " Step 1 upgrade completed"
echo "======================================"
echo "Run:"
echo "python3 app.py"
