#!/usr/bin/env bash
set -euo pipefail

# Feel the AGI — One-command setup
# Downloads the project, installs dependencies, authenticates Claude Code,
# starts the coordination server, and opens the dashboard.

REPO_URL="https://github.com/HappyRobotsCo/feel-the-agi-app"
PROJECT_DIR="$HOME/feel-the-agi"
PID_FILE="$PROJECT_DIR/.server.pid"
SERVER_PORT=3456

# --- Helpers ---
print_step() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_ok() {
  echo "  ✓ $1"
}

print_skip() {
  echo "  → $1"
}

print_info() {
  echo "  $1"
}

# --- Step 1/5: Download project ---
print_step "[1/5] Downloading project"

if [ -f "$PROJECT_DIR/server.js" ] && [ -f "$PROJECT_DIR/launch.sh" ]; then
  print_skip "Already downloaded"
else
  print_info "Downloading from GitHub..."
  mkdir -p "$PROJECT_DIR"
  curl -sL "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz -C "$PROJECT_DIR" --strip-components=1
  print_ok "Downloaded to $PROJECT_DIR"
fi

# IMPORTANT: cd into the project directory before running any claude commands.
# Claude Code scans from CWD on startup looking for .git/CLAUDE.md files.
# If CWD is $HOME (the default when piped from curl), it walks ~/Desktop,
# ~/Documents, ~/Photos, ~/Contacts, etc. and triggers a macOS TCC permission
# popup for EACH protected folder.
cd "$PROJECT_DIR"

# --- Step 2/5: Install dependencies ---
print_step "[2/5] Installing dependencies"

# Homebrew
if command -v brew > /dev/null 2>&1; then
  print_skip "Homebrew already installed"
else
  print_info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  print_ok "Homebrew"
fi

# Node.js
if command -v node > /dev/null 2>&1; then
  print_skip "Node.js $(node --version) already installed"
else
  print_info "Installing Node.js..."
  brew install node < /dev/null > /dev/null 2>&1
  print_ok "Node.js $(node --version)"
fi

# Claude Code
if command -v claude > /dev/null 2>&1; then
  print_skip "Claude Code already installed"
else
  print_info "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code < /dev/null > /dev/null 2>&1
  print_ok "Claude Code"
fi

# Project npm dependencies
if [ -d "$PROJECT_DIR/node_modules/ws" ] && [ -d "$PROJECT_DIR/node_modules/chokidar" ]; then
  print_skip "Project dependencies already installed"
else
  print_info "Installing project dependencies..."
  npm install < /dev/null > /dev/null 2>&1
  print_ok "Project dependencies"
fi

# --- Step 3/5: Sign in to Claude ---
print_step "[3/5] Signing in to Claude"

# Check auth via "auth status" — lightweight JSON check, no session launch,
# no directory scanning, no macOS TCC popups.
# Redirect stdin from /dev/null so claude doesn't consume the piped script
# (this script is run via `curl | bash`, so stdin IS the script itself).
if claude auth status < /dev/null 2>/dev/null | grep -q '"loggedIn": true'; then
  print_skip "Already signed in"
else
  print_info "A browser window will open — sign in to your Anthropic account."
  echo ""
  if claude auth login < /dev/tty 2>/dev/null || claude auth login; then
    print_ok "Signed in"
  else
    print_info ""
    print_info "Authentication failed. Run this script again after signing in."
    exit 1
  fi
fi

# --- Step 4/5: Gmail (optional, non-blocking) ---
print_step "[4/5] Checking Gmail"

GMAIL_AUTH_STATUS=$(claude mcp list < /dev/null 2>&1 | grep "claude.ai Gmail" || true)
if echo "$GMAIL_AUTH_STATUS" | grep -q "Connected"; then
  print_skip "Gmail connected"
else
  print_skip "Gmail not connected — email triage will be skipped"
  print_skip "You can connect later from the dashboard"
fi

# --- Step 5/5: Launch ---
print_step "[5/5] Launching"

# Create directory structure
mkdir -p "$PROJECT_DIR"/{status,output}

# Kill any existing server on our port
if lsof -i ":$SERVER_PORT" > /dev/null 2>&1; then
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    sleep 1
  fi
  lsof -ti ":$SERVER_PORT" | xargs kill -9 2>/dev/null || true
  sleep 1
fi

# Start server in the background
node server.js &
SERVER_PID=$!

# Wait for server to be ready
for i in $(seq 1 20); do
  if curl -sf "http://localhost:$SERVER_PORT/health" > /dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "  Server failed to start."
    kill "$SERVER_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 0.5
done

# Save PID
if [ ! -f "$PID_FILE" ]; then
  echo "$SERVER_PID" > "$PID_FILE"
fi

# Open dashboard
open "http://localhost:$SERVER_PORT"

# --- Done ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Ready! Dashboard is open in your browser."
echo ""
echo "  Enter your LinkedIn URL and click Launch."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
