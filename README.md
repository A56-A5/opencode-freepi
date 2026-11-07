# opencode-freepi

Free Pi provider connector for [opencode](https://opencode.ai) — use Free Pi's free unlimited AI models directly in your terminal.

## What's included

| File | Purpose |
|------|---------|
| `plugins/freepi-session.ts` | Pins all Free Pi traffic to one session (avoids 4-session cap) |
| `scripts/freepi-ads.py` | Background ad impressions so free tier stays active |
| `config/opencode.example.json` | Example opencode config with Free Pi provider |
| `install.sh` | One-command installer for any Linux distro |
| `uninstall.sh` | Clean removal |

## Free unlimited models

- `particle` — Particle
- `deepseek-v4.1-flash` — DeepSeek V4.1 Flash (reasoning)
- `glm-5.3-flash` — GLM 5.3 Flash (reasoning)

Other models consume credits from your daily allowance (20,000/day, refills 00:00 UTC).

## Prerequisites

- **Linux** (any distro with bash)
- **Python 3.8+**
- **opencode** — [install guide](https://opencode.ai/docs/)
- **Node.js** (npm/pnpm/yarn/bun) — for free-pi-cli and plugin deps

### Installing prerequisites per distro

<details>
<summary><b>Debian / Ubuntu / Mint</b></summary>

```bash
sudo apt update
sudo apt install -y python3 curl git
# Node.js (via NodeSource LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
```
</details>

<details>
<summary><b>Fedora / RHEL / CentOS Stream</b></summary>

```bash
sudo dnf install -y python3 curl git nodejs
```
</details>

<details>
<summary><b>Arch / Manjaro / EndeavourOS</b></summary>

```bash
sudo pacman -S --needed python curl git nodejs npm
```
</details>

<details>
<summary><b>openSUSE Leap / Tumbleweed</b></summary>

```bash
sudo zypper install -y python3 curl git nodejs npm
```
</details>

<details>
<summary><b>Alpine</b></summary>

```bash
sudo apk add python3 curl git nodejs npm
```
</details>

<details>
<summary><b>NixOS</b></summary>

```bash
# Add to environment.systemPackages in configuration.nix:
# python3 curl git nodejs
sudo nixos-rebuild switch
```
</details>

<details>
<summary><b>Void Linux</b></summary>

```bash
sudo xbps-install -S python3 curl git nodejs
```
</details>

<details>
<summary><b>Gentoo</b></summary>

```bash
sudo emerge dev-lang/python net-misc/curl dev-vcs/git nodejs
```
</details>

<details>
<summary><b>opencode itself</b></summary>

```bash
# One-liner (any distro)
curl -fsSL https://opencode.ai/install | bash
# Or via npm
npm install -g opencode-ai
```
</details>

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/opencode-freepi.git
cd opencode-freepi
chmod +x install.sh uninstall.sh
./install.sh
```

The installer will:

1. Install `free-pi-cli` if missing (via your package manager)
2. Run `free-pi login` and save your API key to `~/.config/opencode/freepi.key`
3. Copy the session-pinning plugin to `~/.config/opencode/plugins/`
4. Copy the ad impression script to `~/.config/opencode/scripts/`
5. Merge the Free Pi provider into your existing `opencode.json` (non-destructive)
6. Install plugin npm dependencies
7. Set up a systemd user service for background ad impressions

**Restart opencode** after installation.

## Verify it works

```bash
# Check your Free Pi account (should show remaining credits)
curl -s -H "Authorization: Bearer $(cat ~/.config/opencode/freepi.key)" \
  https://api.freepi.ai/me | python3 -m json.tool

# Check the ad service is running
systemctl --user status freepi-ads

# In opencode, pick a free model:
#   /model freepi/deepseek-v4.1-flash
```

## Manual installation

If you prefer not to use `install.sh`:

1. **Login to Free Pi:**
   ```bash
   npm install -g free-pi-cli
   free-pi login
   ```

2. **Save your API key:**
   ```bash
   TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.free-pi/agent/credentials.json'))['token'])")
   mkdir -p ~/.config/opencode
   echo -n "$TOKEN" > ~/.config/opencode/freepi.key
   chmod 600 ~/.config/opencode/freepi.key
   ```

3. **Copy files:**
   ```bash
   mkdir -p ~/.config/opencode/{plugins,scripts}
   cp plugins/freepi-session.ts ~/.config/opencode/plugins/
   cp scripts/freepi-ads.py ~/.config/opencode/scripts/
   chmod +x ~/.config/opencode/scripts/freepi-ads.py
   ```

4. **Merge config:** Add the `freepi` provider block and plugin path from `config/opencode.example.json` into your `~/.config/opencode/opencode.json`.

5. **Install plugin deps:**
   ```bash
   cd ~/.config/opencode && npm init -y && npm install
   ```

6. **Run ad impressions** (background):
   ```bash
   python3 ~/.config/opencode/scripts/freepi-ads.py &
   ```

## Configuration

The key setting in `opencode.json` is the session header, which the plugin handles automatically:

```json
"headers": {
  "x-session-id": "opencode-freepi",
  "x-client-version": "0.6.11"
}
```

Free Pi allows **4 concurrent sessions** per account. The plugin pins all opencode traffic to a single session ID so you never trip the cap.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `429` or session errors | Ensure `freepi-session.ts` is in your `plugins` array and opencode was restarted |
| Ad service not running | `systemctl --user start freepi-ads` or run `python3 ~/.config/opencode/scripts/freepi-ads.py &` |
| `401 Unauthorized` | Token expired. Re-run `free-pi login` and re-copy the key |
| Plugin not loading | Check `npm install` ran in `~/.config/opencode/` |
| Model not found | Ensure `freepi` provider block exists in `opencode.json` |

Check credits anytime:
```bash
curl -s -H "Authorization: Bearer $(cat ~/.config/opencode/freepi.key)" https://api.freepi.ai/me
```

## Uninstall

```bash
./uninstall.sh
```

This removes the plugin, ad script, systemd service, and the `freepi` provider from `opencode.json`. Your API key is left in place (delete manually if desired).

## License

[MIT](LICENSE)
