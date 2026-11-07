#!/usr/bin/env python3
"""Background free-pi ad impressions so free completions stay unpaused.

Mirrors free-pi-cli's banner flow without rendering:
  GET  /ads/next?slot=banner
  GET  <imp_url>          (gravity, if present)
  POST /ads/impression
"""
from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.freepi.ai"
KEY_PATH = Path.home() / ".config" / "opencode" / "freepi.key"
SESSION_ID = "opencode-freepi"
# free-pi-cli: BANNER_REFRESH_MS=10min, BANNER_MIN_REFRESH_MS=60s
INTERVAL_S = 60
IMP_TIMEOUT_S = 3
REQ_TIMEOUT_S = 10


def log(msg: str) -> None:
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} {msg}", flush=True)


def token() -> str:
    return KEY_PATH.read_text(encoding="utf-8").strip()


def authed(path: str, method: str = "GET", body: dict | None = None) -> tuple[int, bytes]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token()}",
            "Content-Type": "application/json",
            "x-session-id": SESSION_ID,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=REQ_TIMEOUT_S) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def fire_gravity(url: str) -> bool:
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=IMP_TIMEOUT_S) as resp:
            resp.read()
        return True
    except Exception:
        return False


def tick(last_token: str | None) -> str | None:
    status, raw = authed("/ads/next?slot=banner")
    if status != 204 and status != 200:
        log(f"ads/next HTTP {status}: {raw[:200]!r}")
        return last_token
    if status == 204 or not raw:
        log("ads/next empty (204)")
        return last_token

    ad = json.loads(raw)
    ad_id = ad.get("ad_id")
    click_token = ad.get("click_token")
    if not ad_id or not click_token:
        log(f"ads/next missing fields: {list(ad)}")
        return last_token

    imp_fired = False
    imp_url = ad.get("imp_url")
    if ad.get("source") == "gravity" and imp_url:
        imp_fired = fire_gravity(imp_url)

    # Always post when token rotates; re-post same token only if never seen
    # (server treats fresh impressions as "ads displaying").
    if click_token != last_token:
        body: dict = {"ad_id": ad_id, "click_token": click_token}
        if imp_fired:
            body["imp_fired"] = True
        status, raw = authed("/ads/impression", method="POST", body=body)
        if status == 200:
            log(f"impression ok ad={ad_id} grav={imp_fired}")
        else:
            log(f"impression HTTP {status}: {raw[:200]!r}")
        return click_token
    return last_token


def main() -> int:
    if not KEY_PATH.is_file():
        log(f"missing key file: {KEY_PATH}")
        return 1
    log(f"start interval={INTERVAL_S}s session={SESSION_ID}")
    last: str | None = None
    while True:
        try:
            last = tick(last)
        except Exception as e:
            log(f"tick error: {e}")
        time.sleep(INTERVAL_S)


if __name__ == "__main__":
    sys.exit(main())
