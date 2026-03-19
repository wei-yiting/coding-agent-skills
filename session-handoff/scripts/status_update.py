#!/usr/bin/env python3
"""
Update the status of a handoff record.

Usage:
    python3 status_update.py --id <handoff-id> --status <new-status>
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

HANDOFF_FILE = Path.home() / ".config" / "session-handoff" / "handoff.json"
VALID_STATUSES = ("open", "pending", "abandoned", "resolved")


def main():
    parser = argparse.ArgumentParser(description="Update handoff status")
    parser.add_argument("--id", required=True, help="Handoff ID to update")
    parser.add_argument(
        "--status",
        required=True,
        choices=VALID_STATUSES,
        help="New status value",
    )
    args = parser.parse_args()

    if not HANDOFF_FILE.exists():
        print(json.dumps({"error": "No handoff file found"}))
        sys.exit(1)

    with open(HANDOFF_FILE) as f:
        records = json.load(f)

    now = datetime.now().astimezone().isoformat()
    found = False
    for r in records:
        if r.get("id") == args.id:
            old_status = r.get("status")
            r["status"] = args.status
            r["updated_at"] = now

            if args.status in ("abandoned", "resolved"):
                r["resolved_at"] = now
            elif args.status == "open" and old_status in ("abandoned", "resolved"):
                r["resolved_at"] = None

            found = True
            break

    if not found:
        print(json.dumps({"error": f"Record '{args.id}' not found"}))
        sys.exit(1)

    tmp = HANDOFF_FILE.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(records, f, indent=2, ensure_ascii=False)
    tmp.rename(HANDOFF_FILE)

    print(json.dumps({"updated_id": args.id, "new_status": args.status}))


if __name__ == "__main__":
    main()
