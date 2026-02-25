# Testing Feel the AGI on a Clean Mac

## Prerequisites

Install Tart (macOS VM tool):

```bash
brew install cirruslabs/cli/tart
```

Pull a clean macOS image and configure it (one-time, ~25GB download):

```bash
tart clone ghcr.io/cirruslabs/macos-sequoia-vanilla:latest golden
tart set golden --cpu 4 --memory 8192 --disk-size 80
```

Install sshpass for headless testing (optional):

```bash
brew install hudochenkov/sshpass/sshpass
```

## Interactive Testing (GUI)

This gives you a Screen Sharing window where you can use the VM like a real user.

```bash
# Create a fresh clone (instant — APFS copy-on-write)
tart clone golden test-run

# Launch with VNC (opens Screen Sharing window)
tart run test-run --vnc-experimental
```

Inside the VM, open Terminal and run:

```bash
curl -sL https://raw.githubusercontent.com/HappyRobotsCo/feel-the-agi-app/main/setup.sh | bash
```

Default VM credentials: `admin` / `admin`

### Reset and Re-test

```bash
tart stop test-run && tart delete test-run
tart clone golden test-run && tart run test-run --vnc-experimental
```

## Headless Testing (SSH)

For automated/scripted testing without a GUI window.

```bash
# Create and boot headless
tart clone golden test-run
tart run test-run --no-graphics &

# Wait for VM to get an IP
until tart ip test-run 2>/dev/null; do sleep 3; done
sleep 5

# SSH in and run the setup script
sshpass -p admin ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  admin@$(tart ip test-run) \
  "curl -sL https://raw.githubusercontent.com/HappyRobotsCo/feel-the-agi-app/main/setup.sh | bash"
```

Note: `claude auth login` requires a browser, so it will fail in headless mode. Steps 1-4 (download, Homebrew, Node, Claude Code install) can still be validated this way.

### Teardown

```bash
tart stop test-run && tart delete test-run
```

## Important Notes

- **Apple limits you to 2 macOS VMs running simultaneously.** Stop old VMs before starting new ones.
- **`tart run` must be run from a real Terminal window** — it won't open a GUI if launched from Claude Code or a background process.
- **`--vnc-experimental`** is the flag that works reliably for interactive testing. Plain `tart run` (native window) doesn't always show a window.
- Each fresh clone has a pristine macOS with **no Homebrew, no Node, no Claude Code, no TCC permissions granted** — identical to a new user's machine.
- Clones are instant on APFS and only consume disk space as the guest diverges from the golden image.

## What to Test

1. **No TCC popups** — The setup script should complete without macOS asking for access to Photos, Contacts, Desktop, etc.
2. **All 8 steps complete** — Download, Homebrew, Node, Claude Code, Auth, Gmail, Scaffolding, Server
3. **curl | bash works** — The script shouldn't stall or silently exit mid-way (stdin consumption bug)
4. **Dashboard opens** — Browser should open to http://localhost:3456 after setup
