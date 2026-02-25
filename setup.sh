#!/usr/bin/env bash
set -euo pipefail

# Feel the AGI — One-command setup
# Downloads the project, installs dependencies, authenticates Claude Code,
# connects Gmail, starts the coordination server, and opens the dashboard.

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
  echo "  → Already installed: $1"
}

print_error() {
  echo "  ✗ $1" >&2
}

# --- Step 1/8: Download project ---
print_step "[1/8] Downloading Feel the AGI"

if [ -f "$PROJECT_DIR/server.js" ] && [ -f "$PROJECT_DIR/launch.sh" ]; then
  print_skip "Project files (already downloaded)"
else
  echo "  Downloading from GitHub..."
  mkdir -p "$PROJECT_DIR"
  curl -sL "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz -C "$PROJECT_DIR" --strip-components=1
  print_ok "Project downloaded to $PROJECT_DIR"
fi

# IMPORTANT: cd into the project directory before running any claude commands.
# Claude Code scans from CWD on startup looking for .git/CLAUDE.md files.
# If CWD is $HOME (the default when piped from curl), it walks ~/Desktop,
# ~/Documents, ~/Photos, ~/Contacts, etc. and triggers a macOS TCC permission
# popup for EACH protected folder — which scares users into quitting.
cd "$PROJECT_DIR"

# --- Step 2/8: Homebrew ---
print_step "[2/8] Checking Homebrew"

if command -v brew > /dev/null 2>&1; then
  print_skip "Homebrew"
else
  echo "  Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon Macs
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  print_ok "Homebrew installed"
fi

# --- Step 3/8: Node.js ---
print_step "[3/8] Checking Node.js"

if command -v node > /dev/null 2>&1; then
  print_skip "Node.js ($(node --version))"
else
  echo "  Installing Node.js via Homebrew..."
  brew install node < /dev/null > /dev/null 2>&1
  print_ok "Node.js installed ($(node --version))"
fi

# --- Step 4/8: Claude Code ---
print_step "[4/8] Checking Claude Code"

if command -v claude > /dev/null 2>&1; then
  print_skip "Claude Code"
else
  echo "  Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code < /dev/null > /dev/null 2>&1
  print_ok "Claude Code installed"
fi

# --- Step 5/8: Claude authentication ---
print_step "[5/8] Authenticating Claude Code"

# Check auth via "auth status" — lightweight JSON check, no session launch,
# no directory scanning, no macOS TCC popups.
# Redirect stdin from /dev/null so claude doesn't consume the piped script
# (this script is run via `curl | bash`, so stdin IS the script itself).
if claude --version < /dev/null > /dev/null 2>&1 && claude auth status < /dev/null 2>/dev/null | grep -q '"loggedIn": true'; then
  print_skip "Claude Code (already authenticated)"
else
  echo "  Starting Claude Code authentication..."
  echo "  A browser window will open. Please sign in to your Anthropic account."
  echo ""
  if claude auth login < /dev/tty 2>/dev/null || claude auth login; then
    print_ok "Claude Code authenticated"
  else
    print_error "Authentication failed or was cancelled."
    echo "  Please run this script again after authenticating."
    exit 1
  fi
fi

# Pre-seed Claude Code config to skip first-run onboarding wizard and the
# --dangerously-skip-permissions confirmation dialog. Without this, each
# mission window shows an interactive theme picker / tutorial instead of
# running the actual agent.
CLAUDE_VERSION=$(claude --version < /dev/null 2>/dev/null || echo "unknown")
if [ ! -f "$HOME/.claude.json" ] || ! grep -q '"hasCompletedOnboarding"' "$HOME/.claude.json" 2>/dev/null; then
  cat > "$HOME/.claude.json" << EOF
{
  "hasCompletedOnboarding": true,
  "theme": "dark",
  "numStartups": 1,
  "lastOnboardingVersion": "$CLAUDE_VERSION"
}
EOF
  print_ok "Claude Code onboarding pre-configured"
fi

mkdir -p "$HOME/.claude"
if [ ! -f "$HOME/.claude/settings.json" ]; then
  cat > "$HOME/.claude/settings.json" << 'EOF'
{
  "skipDangerousModePermissionPrompt": true
}
EOF
elif ! grep -q '"skipDangerousModePermissionPrompt"' "$HOME/.claude/settings.json" 2>/dev/null; then
  # Settings file exists but missing the key — add it via a temp file
  node -e "
    const fs = require('fs');
    const f = '$HOME/.claude/settings.json';
    const s = JSON.parse(fs.readFileSync(f, 'utf8'));
    s.skipDangerousModePermissionPrompt = true;
    fs.writeFileSync(f, JSON.stringify(s, null, 2) + '\n');
  " < /dev/null 2>/dev/null || true
fi

# --- Step 6/8: Gmail authentication ---
print_step "[6/8] Connecting Gmail"

# Claude Code has a built-in Gmail MCP server (claude.ai Gmail) that requires
# a one-time OAuth flow through Google. No extra software needed.

# Check if Gmail is already authenticated
GMAIL_AUTH_STATUS=$(claude mcp list < /dev/null 2>&1 | grep "claude.ai Gmail" || true)

if echo "$GMAIL_AUTH_STATUS" | grep -q "Connected"; then
  print_skip "Gmail (already connected)"
else
  echo ""
  echo "  Gmail needs a one-time connection to your Google account."
  echo ""
  echo "  Two options:"
  echo "    A) Visit https://claude.ai/settings/connectors in your browser"
  echo "       → Click 'Connect' next to Gmail → Sign in with Google"
  echo ""
  echo "    B) In a separate terminal, run: claude"
  echo "       → Type /mcp → Select 'Authenticate' for Gmail"
  echo ""
  echo "  After connecting, press Enter to continue..."
  read -r < /dev/tty 2>/dev/null || true

  # Re-check
  GMAIL_AUTH_STATUS=$(claude mcp list < /dev/null 2>&1 | grep "claude.ai Gmail" || true)
  if echo "$GMAIL_AUTH_STATUS" | grep -q "Connected"; then
    print_ok "Gmail connected"
  else
    echo ""
    echo "  ⚠ Gmail still shows as not connected."
    echo "  The demo will still launch, but Mission 2 (Email Triage)"
    echo "  won't be able to read your emails."
    echo ""
    echo "  You can connect Gmail later via https://claude.ai/settings/connectors"
    echo ""
  fi
fi

# --- Step 7/8: Project scaffolding ---
print_step "[7/8] Setting up project"

# Create directory structure (idempotent — mkdir -p)
mkdir -p "$PROJECT_DIR"/{status,output}
print_ok "Directory structure ready"

# Ensure npm dependencies are installed
if [ -d "$PROJECT_DIR/node_modules" ] && [ -d "$PROJECT_DIR/node_modules/ws" ] && [ -d "$PROJECT_DIR/node_modules/chokidar" ]; then
  print_skip "npm dependencies"
else
  echo "  Installing npm dependencies..."
  npm install < /dev/null > /dev/null 2>&1
  print_ok "npm dependencies installed"
fi

# --- Step 8/8: Start coordination server ---
print_step "[8/8] Starting coordination server"

# Kill any existing server on our port
if lsof -i ":$SERVER_PORT" > /dev/null 2>&1; then
  echo "  Port $SERVER_PORT already in use — stopping existing server..."
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    sleep 1
  fi
  # Force-kill anything still on the port
  lsof -ti ":$SERVER_PORT" | xargs kill -9 2>/dev/null || true
  sleep 1
  print_ok "Existing server stopped"
fi

# Start server in the background
node server.js &
SERVER_PID=$!

# Wait for server to be ready (up to 10 seconds)
echo "  Waiting for server to start..."
for i in $(seq 1 20); do
  if curl -sf "http://localhost:$SERVER_PORT/health" > /dev/null 2>&1; then
    print_ok "Server running on port $SERVER_PORT (PID: $SERVER_PID)"
    break
  fi
  if [ "$i" -eq 20 ]; then
    print_error "Server failed to start within 10 seconds"
    kill "$SERVER_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 0.5
done

# Verify PID file was written by the server
if [ -f "$PID_FILE" ]; then
  print_ok "PID file: $PID_FILE"
else
  # Server writes its own PID file, but just in case
  echo "$SERVER_PID" > "$PID_FILE"
  print_ok "PID file written: $PID_FILE"
fi

# Open dashboard in default browser
open "http://localhost:$SERVER_PORT"
print_ok "Dashboard opened in browser"

# --- Done! ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup complete!"
echo ""
echo "  Dashboard: http://localhost:$SERVER_PORT"
echo "  Server PID: $(cat "$PID_FILE")"
echo ""
echo "  Next steps:"
echo "    1. Enter your LinkedIn URL in the dashboard"
echo "    2. Click Launch!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
