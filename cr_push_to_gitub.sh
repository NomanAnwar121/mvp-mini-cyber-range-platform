#!/bin/bash

# --- CONFIG ---
REPO_NAME="mvp-mini-cyber-range-platform"   # Change this to your GitHub repo name
PRIVATE=false            # Set true for private repo, false for public

# --- SCRIPT ---
echo "[+] Starting GitHub push automation..."

# Go to current folder (or you can cd to your project)
PROJECT_DIR=$(pwd)
echo "[+] Project directory: $PROJECT_DIR"

# Initialize git if not already
if [ ! -d ".git" ]; then
    git init
    echo "[+] Git initialized."
fi

# Add all files
git add .
echo "[+] All files added."

# Commit changes
git commit -m "Initial commit" 2>/dev/null || echo "[!] Nothing to commit, skipping commit."

# Make sure branch is main
git branch -M main

# Create GitHub repo via gh CLI
if [ "$PRIVATE" = true ]; then
    gh repo create "$REPO_NAME" --private --source="$PROJECT_DIR" --remote=origin --push
else
    gh repo create "$REPO_NAME" --public --source="$PROJECT_DIR" --remote=origin --push
fi

echo "[✓] Done! Your project has been pushed to GitHub."
