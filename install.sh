#!/usr/bin/env bash
# opencode-freepi installer — works on any Linux distro with bash + python3
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OC_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
FREepi_KEY="$OC_CONFIG/freepi.key"
PLUGIN_DEST="$OC_CONFIG/plugins"
SCRIPT_DEST="$OC_CONFIG/scripts"
SERVICE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }

# ── Preconditions ──────────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || { err "python3 not found. Install it first:"; \
  err "  Debian/Ubuntu: sudo apt install python3"; \
  err "  Fedora:        sudo dnf install python3"; \
  err "  Arch:          sudo pacman -S python"; \
  err "  openSUSE:      sudo zypper install python3"; exit 1; }

command -v opencode >/dev/null 2>&1 || { err "opencode not found in PATH."; \
  err "Install it first: https://opencode.ai/docs/"; exit 1; }

# ── free-pi-cli ────────────────────────────────────────────────────
if ! command -v free-pi >/dev/null 2>&1; then
  warn "free-pi-cli not found. Installing..."
  if command -v npm >/dev/null 2>&1; then
    npm install -g free-pi-cli
  elif command -v pnpm >/dev/null 2>&1; then
    pnpm add -g free-pi-cli
  elif command -v yarn >/dev/null 2>&1; then
    yarn global add free-pi-cli
  elif command -v bun >/dev/null 2>&1; then
    bun add -g free-pi-cli
  else
    err "No JS package manager found (npm/pnpm/yarn/bun). Install one first."
    exit 1
  fi
  info "free-pi-cli installed"
else
  info "free-pi-cli already installed ($(free-pi --version 2>/dev/null || echo 'version unknown'))"
fi

# ── Free Pi login + API key ───────────────────────────────────────
if [ ! -f "$FREepi_KEY" ]; then
  info "No API key found. Starting free-pi login..."
  free-pi login || { err "free-pi login failed"; exit 1; }

  # Extract token from credentials
  CREDS="$HOME/.free-pi/agent/credentials.json"
  if [ -f "$CREDS" ]; then
    TOKEN=$(python3 -c "import json; print(json.load(open('$CREDS'))['token'])" 2>/dev/null || true)
    if [ -z "$TOKEN" ]; then
      TOKEN=$(python3 -c "import json; d=json.load(open('$CREDS')); print(d.get('access_token') or d.get('token') or '')" 2>/dev/null || true)
    fi
    if [ -n "$TOKEN" ]; then
      echo -n "$TOKEN" > "$FREepi_KEY"
      chmod 600 "$FREepi_KEY"
      info "API key saved to $FREepi_KEY"
    else
      warn "Could not auto-extract token. Copy it manually:"
      warn "  cat ~/.free-pi/agent/credentials.json"
      warn "  then: echo '<token>' > $FREepi_KEY"
    fi
  else
    warn "Credentials file not found at $CREDS"
    warn "Copy your token manually: echo '<token>' > $FREepi_KEY"
  fi
else
  info "API key already present"
fi

# ── Plugin ─────────────────────────────────────────────────────────
mkdir -p "$PLUGIN_DEST"
cp "$REPO_DIR/plugins/freepi-session.ts" "$PLUGIN_DEST/"
info "Plugin installed to $PLUGIN_DEST/freepi-session.ts"

# ── Ad impression script ──────────────────────────────────────────
mkdir -p "$SCRIPT_DEST"
cp "$REPO_DIR/scripts/freepi-ads.py" "$SCRIPT_DEST/"
chmod +x "$SCRIPT_DEST/freepi-ads.py"
info "Ad script installed to $SCRIPT_DEST/freepi-ads.py"

# ── opencode.json merge ───────────────────────────────────────────
OC_JSON="$OC_CONFIG/opencode.json"
if [ -f "$OC_JSON" ]; then
  if python3 -c "import json; json.load(open('$OC_JSON'))" 2>/dev/null; then
    python3 <<PYEOF
import json, sys
cfg_path = "$OC_JSON"
with open(cfg_path) as f:
    cfg = json.load(f)

# Add plugin if missing
plugins = cfg.get("plugins", [])
plugin_path = "~/.config/opencode/plugins/freepi-session.ts"
if plugin_path not in plugins:
    plugins.append(plugin_path)
cfg["plugins"] = plugins

# Add freepi provider if missing
if "provider" not in cfg:
    cfg["provider"] = {}
if "freepi" not in cfg["provider"]:
    example = json.load(open("$REPO_DIR/config/opencode.example.json"))
    cfg["provider"]["freepi"] = example["provider"]["freepi"]
    info_msg = True
else:
    info_msg = False

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

if info_msg:
    print("  freepi provider added to opencode.json")
else:
    print("  freepi provider already in opencode.json")
PYEOF
    info "opencode.json updated"
  else
    warn "opencode.json exists but is not valid JSON. Skipping merge."
    warn "Manually merge from config/opencode.example.json"
  fi
else
  mkdir -p "$OC_CONFIG"
  cp "$REPO_DIR/config/opencode.example.json" "$OC_JSON"
  info "Created $OC_JSON from example"
fi

# ── npm dependency for plugin ─────────────────────────────────────
if [ -f "$OC_CONFIG/package.json" ]; then
  (cd "$OC_CONFIG" && npm install --silent 2>/dev/null || true)
  info "Plugin dependencies installed"
else
  (cd "$OC_CONFIG" && npm init -y >/dev/null 2>&1 && npm install --silent 2>/dev/null || true)
  info "Initialized npm and installed plugin dependencies"
fi

# ── systemd user service for ad impressions ──────────────────────
if command -v systemctl >/dev/null 2>&1 && [ -d "$HOME/.config/systemd" ]; then
  mkdir -p "$SERVICE_DIR"
  cat > "$SERVICE_DIR/freepi-ads.service" <<EOF
[Unit]
Description=Free Pi ad impressions (keeps free tier active)
After=network-online.target

[Service]
Type=simple
ExecStart=$(which python3) $SCRIPT_DEST/freepi-ads.py
Restart=on-failure
RestartSec=30

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable freepi-ads.service 2>/dev/null || true
  systemctl --user start freepi-ads.service 2>/dev/null || true
  info "systemd user service installed and started"
else
  warn "systemd not available. Start ad impressions manually:"
  warn "  python3 $SCRIPT_DEST/freepi-ads.py &"
fi

echo ""
info "Done! Restart opencode to pick up changes."
info "Free unlimited models: particle, deepseek-v4.1-flash, glm-5.3-flash"
