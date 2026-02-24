#!/usr/bin/env bash
set -uo pipefail

# Feel the AGI — Cleanup script
# Kills all demo processes, prompts before each file removal.
# Safe to run multiple times.

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

confirm() {
  local prompt="$1"
  local answer
  printf "  %s (y/n) " "$prompt"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# --- Step 1/3: Kill demo processes ---
print_step "[1/3] Stopping demo processes"

# Kill coordination server via PID file
if [ -f "$PID_FILE" ]; then
  SERVER_PID=$(cat "$PID_FILE")
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    print_ok "Coordination server stopped (PID: $SERVER_PID)"
  else
    print_skip "Server PID $SERVER_PID not running"
  fi
  rm -f "$PID_FILE"
else
  print_skip "No PID file found"
fi

# Force-kill anything still on the server port
if lsof -ti ":$SERVER_PORT" > /dev/null 2>&1; then
  lsof -ti ":$SERVER_PORT" | xargs kill 2>/dev/null || true
  sleep 0.5
  # Force kill if still hanging
  lsof -ti ":$SERVER_PORT" | xargs kill -9 2>/dev/null || true
  print_ok "Killed remaining processes on port $SERVER_PORT"
fi

# Kill claude agent processes
if pgrep -f '[c]laude --dangerously-skip-permissions' > /dev/null 2>&1; then
  pkill -f '[c]laude --dangerously-skip-permissions' 2>/dev/null || true
  print_ok "Claude agent processes stopped"
else
  print_skip "No claude agent processes running"
fi

# Kill Next.js dev server on port 3000
if lsof -ti :3000 > /dev/null 2>&1; then
  lsof -ti :3000 | xargs kill 2>/dev/null || true
  print_ok "Next.js dev server stopped (port 3000)"
else
  print_skip "No process on port 3000"
fi

# --- Step 2/3: Prompt for file removal ---
print_step "[2/3] Clean up generated files"

# Remove generated website (skill prompt creates it at output/site/)
if [ -d "$PROJECT_DIR/output/site" ] || [ -d "$PROJECT_DIR/output/website" ] || ls "$PROJECT_DIR"/output/website-* > /dev/null 2>&1; then
  if confirm "Remove the generated website?"; then
    rm -rf "$PROJECT_DIR"/output/site "$PROJECT_DIR"/output/website "$PROJECT_DIR"/output/website-*
    print_ok "Generated website removed"
  else
    print_skip "Kept generated website"
  fi
else
  print_skip "No generated website found"
fi

# Remove email summaries
if [ -d "$PROJECT_DIR/output/email-summary" ]; then
  if confirm "Remove email summaries?"; then
    rm -rf "$PROJECT_DIR/output/email-summary"
    print_ok "Email summaries removed"
  else
    print_skip "Kept email summaries"
  fi
else
  print_skip "No email summaries found"
fi

# Remove documents report (includes undo.sh)
if [ -d "$PROJECT_DIR/output/documents-report" ]; then
  if confirm "Remove documents report?"; then
    rm -rf "$PROJECT_DIR/output/documents-report"
    print_ok "Documents report removed"
  else
    print_skip "Kept documents report"
  fi
else
  print_skip "No documents report found"
fi

# Revoke Gmail token
if [ -f "$PROJECT_DIR/.credentials/gmail-token.json" ]; then
  if confirm "Revoke Gmail token?"; then
    rm -f "$PROJECT_DIR/.credentials/gmail-token.json"
    print_ok "Gmail token revoked"
  else
    print_skip "Kept Gmail token"
  fi
else
  print_skip "No Gmail token found"
fi

# Remove entire project directory
if [ -d "$PROJECT_DIR" ]; then
  if confirm "Remove the entire ~/feel-the-agi directory?"; then
    rm -rf "$PROJECT_DIR"
    print_ok "Project directory removed"
  else
    print_skip "Kept project directory"
  fi
fi

# --- Step 3/3: Done ---
print_step "[3/3] Cleanup complete"

echo ""
echo "  All demo processes have been stopped."
if [ -d "$PROJECT_DIR" ]; then
  echo "  Project directory retained at: $PROJECT_DIR"
else
  echo "  Project directory has been removed."
fi
echo ""
echo "  Note: Claude Code was NOT uninstalled."
echo "  To uninstall it: npm uninstall -g @anthropic-ai/claude-code"
echo ""
