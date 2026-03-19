#!/usr/bin/env python3
"""
Save a handoff record to ~/.config/session-handoff/handoff.json.

Handles:
- Dedup: optionally replace an existing record by ID (--replace-id)
- Cleanup: remove resolved/abandoned records older than 7 days
- Atomic write: temp file + rename

Usage:
    echo '<json_record>' | python3 save.py [--replace-id <id>]
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

HANDOFF_DIR = Path.home() / ".config" / "session-handoff"
HANDOFF_FILE = HANDOFF_DIR / "handoff.json"
EXPIRY_DAYS = 7


def load_records():
    if not HANDOFF_FILE.exists():
        return []
    try:
        with open(HANDOFF_FILE) as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except (json.JSONDecodeError, IOError):
        return []


def save_records(records):
    HANDOFF_DIR.mkdir(parents=True, exist_ok=True)
    tmp = HANDOFF_FILE.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(records, f, indent=2, ensure_ascii=False)
    tmp.rename(HANDOFF_FILE)


def parse_iso(s):
    try:
        return datetime.fromisoformat(s)
    except (ValueError, TypeError):
        return None


def cleanup_expired(records):
    cutoff = datetime.now(timezone.utc) - timedelta(days=EXPIRY_DAYS)
    result = []
    cleaned = 0
    for r in records:
        if r.get("status") in ("resolved", "abandoned"):
            updated = parse_iso(r.get("updated_at", ""))
            if updated and updated.astimezone(timezone.utc) < cutoff:
                cleaned += 1
                continue
        result.append(r)
    return result, cleaned


def main():
    parser = argparse.ArgumentParser(description="Save a handoff record")
    parser.add_argument("--replace-id", help="Replace existing record with this ID")
    args = parser.parse_args()

    new_record = json.load(sys.stdin)
    records = load_records()

    replaced = False
    if args.replace_id:
        original_len = len(records)
        records = [r for r in records if r.get("id") != args.replace_id]
        replaced = len(records) < original_len

    records, cleaned = cleanup_expired(records)
    records.append(new_record)
    save_records(records)

    result = {
        "saved_id": new_record.get("id", "unknown"),
        "total_records": len(records),
    }
    if args.replace_id:
        result["replaced_id"] = args.replace_id
        result["replacement_applied"] = replaced
    if cleaned > 0:
        result["expired_cleaned"] = cleaned

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
