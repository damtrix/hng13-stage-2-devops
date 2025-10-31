#!/usr/bin/env python3
"""Simple log watcher that tails Nginx logs and posts alerts to Slack.

Features:
- Detect pool flips (blue <-> green) based on upstream header in the nginx access log
- Maintain sliding window of requests and detect elevated 5xx rates
- Enforce cooldowns and support maintenance mode suppression

This script reads config from environment variables (see env.template).
"""
import os
import time
import re
import json
import logging
from collections import deque

import requests

LOG_PATH = os.getenv("NGINX_LOG_PATH", "/var/log/nginx/custom_access.log")
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL")
ACTIVE_POOL = os.getenv("ACTIVE_POOL", "blue").lower()
ERROR_RATE_THRESHOLD = float(os.getenv("ERROR_RATE_THRESHOLD", "2"))
WINDOW_SIZE = int(os.getenv("WINDOW_SIZE", "200"))
ALERT_COOLDOWN_SEC = int(os.getenv("ALERT_COOLDOWN_SEC", "300"))
MAINTENANCE_MODE = os.getenv("MAINTENANCE_MODE", "false").lower() in ("1", "true", "yes")

logging.basicConfig(level=logging.INFO, format="[%(asctime)s] %(levelname)s: %(message)s")
logger = logging.getLogger("alert_watcher")

# regex to extract key=value tokens like pool=blue upstream_status=200
KV_RE = re.compile(r"(\b[\w_]+)=([^\s]+)")


def send_slack(text: str):
    if not SLACK_WEBHOOK_URL:
        logger.warning("SLACK_WEBHOOK_URL not set — would have sent: %s", text)
        return False
    payload = {"text": text}
    try:
        resp = requests.post(SLACK_WEBHOOK_URL, json=payload, timeout=5)
        if resp.status_code >= 400:
            logger.error("Slack webhook returned %s: %s", resp.status_code, resp.text)
            return False
        return True
    except Exception as e:
        logger.exception("Failed to post to Slack: %s", e)
        return False


def parse_line(line: str) -> dict:
    """Extract tokens from a log line.

    Returns a dict containing at least: status (int or None), pool (str or None)
    """
    fields = {m.group(1): m.group(2).strip('"') for m in KV_RE.finditer(line)}

    # status might appear as status=123 after our change
    status = None
    if "status" in fields:
        try:
            status = int(fields.get("status"))
        except Exception:
            status = None

    # Get pool from either X-App-Pool header or active upstream
    pool = None
    if fields.get("pool"):
        pool = fields.get("pool")
    elif "upstream_addr" in fields:
        # Try to infer pool from upstream address
        upstream = fields.get("upstream_addr")
        if "app-blue" in upstream:
            pool = "blue"
        elif "app-green" in upstream:
            pool = "green"
    
    # Get release from either header or environment
    release = fields.get("release") or "unknown"
    upstream_status = fields.get("upstream_status") or "-"
    upstream_addr = fields.get("upstream_addr") or "-"
    request_time = fields.get("request_time") or "-"
    upstream_response_time = fields.get("upstream_response_time") or "-"

    return {
        "status": status,
        "pool": (pool or "").lower() if pool else None,
        "release": release,
        "upstream_status": upstream_status,
        "upstream_addr": upstream_addr,
        "request_time": request_time,
        "upstream_response_time": upstream_response_time,
        "raw": line,
    }


def tail_file(path: str):
    """Generator that yields new lines appended to path."""
    # wait until file exists
    while not os.path.exists(path):
        logger.info("Waiting for log file %s to appear...", path)
        time.sleep(1)

    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        # seek to end
        fh.seek(0, os.SEEK_END)
        while True:
            line = fh.readline()
            if not line:
                time.sleep(0.1)
                continue
            yield line.rstrip("\n")


def main():
    logger.info("Starting alert_watcher (log=%s) — maintenance=%s", LOG_PATH, MAINTENANCE_MODE)

    window = deque(maxlen=WINDOW_SIZE)
    last_seen_pool = ACTIVE_POOL
    last_alert_time = {"failover": 0, "error_rate": 0}
    alerted_error = False

    for line in tail_file(LOG_PATH):
        data = parse_line(line)

        # Pool flip detection
        pool = data.get("pool")
        if pool and last_seen_pool and pool != last_seen_pool:
            # Detected a pool flip event
            now = time.time()
            if MAINTENANCE_MODE:
                logger.info("Pool flip detected (%s -> %s) but maintenance mode is ON — suppressing alert", last_seen_pool, pool)
            elif now - last_alert_time.get("failover", 0) >= ALERT_COOLDOWN_SEC:
                text = (f":rotating_light: *Failover Detected*\n"
                       f"• From Pool: `{last_seen_pool.upper()}`\n"
                       f"• To Pool: `{pool.upper()}`\n"
                       f"• Release: `{data.get('release')}`\n"
                       f"• Upstream: `{data.get('upstream_addr')}`\n"
                       f"• Status: `{data.get('upstream_status')}`")
                sent = send_slack(text)
                if sent:
                    last_alert_time["failover"] = now
                    logger.info("Sent failover alert: %s -> %s", last_seen_pool, pool)
                else:
                    logger.warning("Failover alert not sent (no webhook)")
            else:
                logger.info("Failover detected but in cooldown window — suppressing")

            last_seen_pool = pool

        # Error-rate tracking — use response status (status)
        status = data.get("status")
        is_5xx = False
        if isinstance(status, int) and 500 <= status < 600:
            is_5xx = True

        # If we don't have a status we still push a None entry (not counted as error)
        window.append(1 if is_5xx else 0)

        # Calculate error rate if we have enough samples (or any samples)
        if len(window) >= 1:
            error_rate = (sum(window) / len(window)) * 100.0
            # Check threshold
            now = time.time()
            if error_rate > ERROR_RATE_THRESHOLD:
                if MAINTENANCE_MODE:
                    logger.info("High error rate (%.2f%%) but maintenance mode ON — suppressing", error_rate)
                elif now - last_alert_time.get("error_rate", 0) >= ALERT_COOLDOWN_SEC:
                    text = (f":warning: *Elevated Error Rate*\n"
                           f"• Rate: `{error_rate:.2f}%` over last {len(window)} requests\n"
                           f"• Threshold: `{ERROR_RATE_THRESHOLD}%`\n"
                           f"• Active Pool: `{pool.upper() if pool else 'UNKNOWN'}`\n"
                           f"• Last Upstream: `{data.get('upstream_addr')}`\n"
                           f"• Last Status: `{data.get('upstream_status')}`")
                    sent = send_slack(text)
                    if sent:
                        last_alert_time["error_rate"] = now
                        alerted_error = True
                        logger.info("Sent error-rate alert: %.2f%%", error_rate)
                    else:
                        logger.warning("Error-rate alert not sent (no webhook)")
                else:
                    logger.debug("Error-rate high but in cooldown (%.2f%%)", error_rate)
            else:
                # If previously alerted and we recovered, send a recovery notice (respect cooldown separately)
                if alerted_error and now - last_alert_time.get("error_rate", 0) >= ALERT_COOLDOWN_SEC:
                    text = f":white_check_mark: Error rate recovered: {error_rate:.2f}% over last {len(window)} requests. Pool: {pool}"
                    sent = send_slack(text)
                    if sent:
                        last_alert_time["error_rate"] = now
                        alerted_error = False
                        logger.info("Sent error-rate recovery alert")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Shutting down alert_watcher")
    except Exception:
        logger.exception("Unhandled exception in alert_watcher")
