#!/usr/bin/env python3
"""
Close a handoff record by marking it as resolved.

Usage:
    python3 close.py --id <handoff-id>
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

HANDOFF_FILE = Path.home() / ".config" / "session-handoff" / "handoff.json"


def main():
    parser = argparse.ArgumentParser(description="Close a handoff record")
    parser.add_argument("--id", required=True, help="Handoff ID to close")
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
            r["status"] = "resolved"
            r["resolved_at"] = now
            r["updated_at"] = now
            found = True
            break

    if not found:
        print(json.dumps({"error": f"Record '{args.id}' not found"}))
        sys.exit(1)

    tmp = HANDOFF_FILE.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(records, f, indent=2, ensure_ascii=False)
    tmp.rename(HANDOFF_FILE)

    print(json.dumps({"closed_id": args.id}))


if __name__ == "__main__":
    main()
