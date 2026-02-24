#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
SKILLS_DIR="$SCRIPT_DIR/skills"

# --- Step 1: Read config.json ---
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: config.json not found at $CONFIG_FILE" >&2
  echo "Please configure via the dashboard first." >&2
  exit 1
fi

# Parse config values using node (already installed as a dependency)
linkedin_url=$(node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8')).linkedin_url || '')")
style_preference=$(node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8')).style_preference || 'Minimal')")
documents_path=$(node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8')).documents_path || '~/Documents')")
documents_prompt=$(node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8')).documents_prompt || '')")

if [ -z "$linkedin_url" ]; then
  echo "ERROR: linkedin_url is empty in config.json" >&2
  exit 1
fi

echo "Config loaded:"
echo "  LinkedIn URL: $linkedin_url"
echo "  Style: $style_preference"
echo "  Documents path: $documents_path"
echo "  Documents prompt: ${documents_prompt:-(none)}"

# --- Step 2: Template skill prompts ---
# Replace {linkedin_url}, {style_preference}, {documents_prompt}, {project_dir} in each skill file
template_skill() {
  local template_file="$1"
  local output_file="$2"

  if [ ! -f "$template_file" ]; then
    echo "WARNING: Template not found: $template_file" >&2
    return 1
  fi

  # Read template content
  local content
  content=$(<"$template_file")

  # Replace placeholders
  content="${content//\{linkedin_url\}/$linkedin_url}"
  content="${content//\{style_preference\}/$style_preference}"
  content="${content//\{documents_path\}/$documents_path}"
  content="${content//\{documents_prompt\}/$documents_prompt}"
  content="${content//\{project_dir\}/$SCRIPT_DIR}"

  # Write templated prompt
  printf '%s' "$content" > "$output_file"
  echo "Templated: $output_file"
}

# Template all three mission skill files
# Templates live as .template.md, output goes to the same name without .template
template_skill "$SKILLS_DIR/research-and-build.template.md" "$SKILLS_DIR/research-and-build.md"
template_skill "$SKILLS_DIR/email-triage.template.md" "$SKILLS_DIR/email-triage.md"
template_skill "$SKILLS_DIR/organize-documents.template.md" "$SKILLS_DIR/organize-documents.md"

echo ""
echo "All skill prompts templated successfully."

# --- Step 2b: Generate launcher scripts ---
# Write small launcher scripts that each mission window will execute
# This avoids quoting issues with AppleScript heredocs
CLAUDE_BIN=$(which claude 2>/dev/null || echo "$HOME/.local/bin/claude")

for i in 1 2 3; do
  case $i in
    1) TITLE="Mission 1: Research & Build Website"; SKILL="research-and-build" ;;
    2) TITLE="Mission 2: Email Triage"; SKILL="email-triage" ;;
    3) TITLE="Mission 3: Organize Documents"; SKILL="organize-documents" ;;
  esac

  SKILL_PATH="$SCRIPT_DIR/skills/${SKILL}.md"

  # Quoted heredoc delimiter ('RUNNER') prevents ALL variable expansion
  cat > "$SCRIPT_DIR/.run-mission${i}.sh" << 'RUNNER'
#!/usr/bin/env bash
set -uo pipefail
unset CLAUDECODE
export PATH="__HOME__/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

echo ''
echo '══════════════════════════════════════════════'
echo '  __TITLE__'
echo '══════════════════════════════════════════════'
echo ''

SKILL_FILE="__SKILL_PATH__"
CLAUDE="__CLAUDE_BIN__"
PROJECT_DIR="__PROJECT_DIR__"

# Change to the project directory so Claude Code picks up .mcp.json
cd "$PROJECT_DIR"

if [ ! -f "$SKILL_FILE" ]; then
  echo "ERROR: Skill file not found: $SKILL_FILE"
  echo "Press Enter to close."
  read
  exit 1
fi

if ! command -v "$CLAUDE" &>/dev/null; then
  echo "ERROR: Claude not found at $CLAUDE"
  echo "Press Enter to close."
  read
  exit 1
fi

echo "[$(date '+%H:%M:%S')] Skill file: $SKILL_FILE ($(wc -c < "$SKILL_FILE" | tr -d ' ') bytes)"
echo "[$(date '+%H:%M:%S')] Claude binary: $CLAUDE"
echo "[$(date '+%H:%M:%S')] Starting agent..."
echo ''

"$CLAUDE" --dangerously-skip-permissions "$(cat "$SKILL_FILE")"

EXIT_CODE=$?
echo ''
echo "[$(date '+%H:%M:%S')] Agent exited with code $EXIT_CODE"
echo "Press Enter to close this window."
read
RUNNER

  # Now do literal string replacements for the values we need baked in
  # Escape & in values since it's special in sed replacement strings
  SAFE_TITLE="${TITLE//&/\\&}"
  sed -i '' "s|__HOME__|$HOME|g" "$SCRIPT_DIR/.run-mission${i}.sh"
  sed -i '' "s|__TITLE__|$SAFE_TITLE|g" "$SCRIPT_DIR/.run-mission${i}.sh"
  sed -i '' "s|__SKILL_PATH__|$SKILL_PATH|g" "$SCRIPT_DIR/.run-mission${i}.sh"
  sed -i '' "s|__CLAUDE_BIN__|$CLAUDE_BIN|g" "$SCRIPT_DIR/.run-mission${i}.sh"
  sed -i '' "s|__PROJECT_DIR__|$SCRIPT_DIR|g" "$SCRIPT_DIR/.run-mission${i}.sh"

done

chmod +x "$SCRIPT_DIR/.run-mission1.sh" "$SCRIPT_DIR/.run-mission2.sh" "$SCRIPT_DIR/.run-mission3.sh"

# --- Step 3: Launch three Terminal.app windows and arrange them ---
RUN1="$SCRIPT_DIR/.run-mission1.sh"
RUN2="$SCRIPT_DIR/.run-mission2.sh"
RUN3="$SCRIPT_DIR/.run-mission3.sh"

echo "Launching three Terminal.app windows..."

osascript <<LAUNCH
use framework "AppKit"

-- Get screen dimensions via visibleFrame (excludes menu bar + Dock)
set fullFrame to current application's NSScreen's mainScreen()'s frame()
set fullHeight to (item 2 of item 2 of fullFrame) as integer
set fullWidth to (item 1 of item 2 of fullFrame) as integer

set visFrame to current application's NSScreen's mainScreen()'s visibleFrame()
set visHeight to (item 2 of item 2 of visFrame) as integer
set visY to (item 2 of item 1 of visFrame) as integer

-- Convert Cocoa bottom-up coords to AppleScript top-down bounds
-- Menu bar height = fullHeight - visHeight - dockHeight
-- Dock height = visY (if dock is at bottom)
set dockHeight to visY
set menuBar to fullHeight - visHeight - dockHeight
set screenWidth to fullWidth
set screenBottom to fullHeight - dockHeight
set usableHeight to screenBottom - menuBar
set halfWidth to (screenWidth / 2) as integer
set thirdHeight to (usableHeight / 3) as integer

tell application "Terminal"
    -- Capture existing window IDs so we only arrange our new ones
    set existingIDs to id of every window

    -- do script without "in" clause = always creates a new window
    do script "bash '$RUN1'"
    delay 0.3
    do script "bash '$RUN2'"
    delay 0.3
    do script "bash '$RUN3'"

    delay 0.5

    -- Find the 3 new windows (IDs not in existingIDs)
    set newWins to {}
    repeat with w in windows
        if existingIDs does not contain (id of w) then
            set end of newWins to w
        end if
    end repeat

    -- Stack new windows on the right half of the screen
    if (count of newWins) >= 3 then
        set bounds of item 1 of newWins to {halfWidth, menuBar, screenWidth, menuBar + thirdHeight}
        set bounds of item 2 of newWins to {halfWidth, menuBar + thirdHeight, screenWidth, menuBar + (thirdHeight * 2)}
        set bounds of item 3 of newWins to {halfWidth, menuBar + (thirdHeight * 2), screenWidth, screenBottom}
    else if (count of newWins) >= 1 then
        repeat with w in newWins
            set bounds of w to {halfWidth, menuBar, screenWidth, screenBottom}
        end repeat
    end if
end tell

-- Position browser on the left half
if application "Google Chrome" is running then
    tell application "Google Chrome"
        if (count of windows) > 0 then
            set bounds of front window to {0, menuBar, halfWidth, screenBottom}
        end if
    end tell
else if application "Safari" is running then
    tell application "Safari"
        if (count of windows) > 0 then
            set bounds of front window to {0, menuBar, halfWidth, screenBottom}
        end if
    end tell
end if

tell application "Terminal" to activate
LAUNCH

echo ""
echo "All three missions launched in Terminal.app."
echo "Windows arranged: browser (left) | Terminal (right, stacked)"
