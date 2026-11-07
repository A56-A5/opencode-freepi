#!/usr/bin/env bash
# opencode-freepi uninstaller
set -euo pipefail

OC_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
PLUGIN_DEST="$OC_CONFIG/plugins"
SCRIPT_DEST="$OC_CONFIG/scripts"
SERVICE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

# Stop service
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user stop freepi-ads.service 2>/dev/null || true
  systemctl --user disable freepi-ads.service 2>/dev/null || true
  rm -f "$SERVICE_DIR/freepi-ads.service"
  systemctl --user daemon-reload 2>/dev/null || true
  info "Stopped and removed systemd service"
fi

# Remove files
rm -f "$PLUGIN_DEST/freepi-session.ts"
rm -f "$SCRIPT_DEST/freepi-ads.py"
info "Removed plugin and ad script"

# Remove freepi provider from opencode.json
OC_JSON="$OC_CONFIG/opencode.json"
if [ -f "$OC_JSON" ]; then
  python3 <<PYEOF
import json
cfg_path = "$OC_JSON"
with open(cfg_path) as f:
    cfg = json.load(f)

# Remove plugin
plugins = cfg.get("plugins", [])
cfg["plugins"] = [p for p in plugins if "freepi-session" not in p]

# Remove provider
if "provider" in cfg and "freepi" in cfg["provider"]:
    del cfg["provider"]["freepi"]

# Remove agent models that reference freepi
for key in ("title", "summary", "compaction"):
    agent = cfg.get("agent", {})
    if key in agent and "freepi" in str(agent[key].get("model", "")):
        del agent[key]

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("  freepi removed from opencode.json")
PYEOF
fi

warn "API key NOT removed. Delete manually if desired:"
warn "  rm $OC_CONFIG/freepi.key"
warn "  rm -rf ~/.free-pi"
echo ""
info "Uninstall complete. Restart opencode."
