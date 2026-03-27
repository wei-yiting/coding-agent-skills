#!/usr/bin/env python3
"""Replay a captured stream-json log through different detection logic versions.

Compares the current (fixed) detection logic against versions with
Bug 3.5 and Bug 4 reintroduced, to demonstrate that these bugs
cause false negatives on real stream data.

Usage:
    python3 scripts/run_eval_bug3_test.py <log-file> <skill-name>
"""

import json
import sys
from pathlib import Path


def detect_fixed(events: list[dict], skill_name: str) -> tuple[bool, list[str]]:
    """Current fixed detection logic (from run_eval.py post-fix)."""
    log = []
    triggered = False
    pending_tool_name = None
    accumulated_json = ""

    for i, event in enumerate(events):
        if event.get("type") == "stream_event":
            se = event.get("event", {})
            se_type = se.get("type", "")

            if se_type == "content_block_start":
                cb = se.get("content_block", {})
                if cb.get("type") == "tool_use":
                    tool_name = cb.get("name", "")
                    if tool_name in ("Skill", "Read"):
                        pending_tool_name = tool_name
                        accumulated_json = ""
                        log.append(f"[{i}] stream/content_block_start: tool_use name={tool_name} -> TRACK")
                    else:
                        pending_tool_name = None
                        accumulated_json = ""
                        log.append(f"[{i}] stream/content_block_start: tool_use name={tool_name} -> RESET, continue")

            elif se_type == "content_block_delta" and pending_tool_name:
                delta = se.get("delta", {})
                if delta.get("type") == "input_json_delta":
                    partial = delta.get("partial_json", "")
                    accumulated_json += partial
                    if skill_name in accumulated_json:
                        log.append(f"[{i}] stream/content_block_delta: MATCH '{skill_name}' in partial JSON")
                        return True, log

            elif se_type == "content_block_stop":
                if pending_tool_name:
                    if skill_name in accumulated_json:
                        log.append(f"[{i}] stream/content_block_stop: MATCH '{skill_name}' in accumulated JSON")
                        return True, log
                    log.append(f"[{i}] stream/content_block_stop: no match for '{skill_name}', reset, continue")
                    pending_tool_name = None
                    accumulated_json = ""

            elif se_type == "message_stop":
                log.append(f"[{i}] stream/message_stop: return triggered={triggered}")
                return triggered, log

        elif event.get("type") == "assistant":
            message = event.get("message", {})
            content_types = [c.get("type") for c in message.get("content", [])]
            has_tool_use = False
            for content_item in message.get("content", []):
                if content_item.get("type") != "tool_use":
                    continue
                has_tool_use = True
                tool_name = content_item.get("name", "")
                tool_input = content_item.get("input", {})
                if tool_name == "Skill" and skill_name in tool_input.get("skill", ""):
                    log.append(f"[{i}] assistant: Skill('{tool_input.get('skill', '')}') -> MATCH")
                    return True, log
                elif tool_name == "Read" and skill_name in tool_input.get("file_path", ""):
                    log.append(f"[{i}] assistant: Read('{tool_input.get('file_path', '')}') -> MATCH")
                    return True, log
                else:
                    log.append(f"[{i}] assistant: tool_use {tool_name}(...) -> no match for '{skill_name}'")
            if has_tool_use:
                log.append(f"[{i}] assistant: had tool_use but none matched -> return False")
                return False, log
            log.append(f"[{i}] assistant: content_types={content_types} -> no tool_use, keep waiting")

        elif event.get("type") == "result":
            log.append(f"[{i}] result: return triggered={triggered}")
            return triggered, log

    log.append(f"[end] exhausted all events, return triggered={triggered}")
    return triggered, log


def detect_bug35(events: list[dict], skill_name: str) -> tuple[bool, list[str]]:
    """Detection with Bug 3.5 reintroduced: non-Skill tool -> return False immediately."""
    log = []
    triggered = False
    pending_tool_name = None
    accumulated_json = ""

    for i, event in enumerate(events):
        if event.get("type") == "stream_event":
            se = event.get("event", {})
            se_type = se.get("type", "")

            if se_type == "content_block_start":
                cb = se.get("content_block", {})
                if cb.get("type") == "tool_use":
                    tool_name = cb.get("name", "")
                    if tool_name in ("Skill", "Read"):
                        pending_tool_name = tool_name
                        accumulated_json = ""
                        log.append(f"[{i}] stream/content_block_start: tool_use name={tool_name} -> TRACK")
                    else:
                        # BUG 3.5: return False immediately
                        log.append(f"[{i}] stream/content_block_start: tool_use name={tool_name} -> BUG 3.5: return False")
                        return False, log

            elif se_type == "content_block_delta" and pending_tool_name:
                delta = se.get("delta", {})
                if delta.get("type") == "input_json_delta":
                    accumulated_json += delta.get("partial_json", "")
                    if skill_name in accumulated_json:
                        log.append(f"[{i}] stream/content_block_delta: MATCH")
                        return True, log

            elif se_type == "content_block_stop":
                if pending_tool_name:
                    if skill_name in accumulated_json:
                        log.append(f"[{i}] stream/content_block_stop: MATCH")
                        return True, log
                    pending_tool_name = None
                    accumulated_json = ""

            elif se_type == "message_stop":
                log.append(f"[{i}] stream/message_stop: return triggered={triggered}")
                return triggered, log

        elif event.get("type") == "assistant":
            message = event.get("message", {})
            content_types = [c.get("type") for c in message.get("content", [])]
            has_tool_use = False
            for content_item in message.get("content", []):
                if content_item.get("type") != "tool_use":
                    continue
                has_tool_use = True
                tool_name = content_item.get("name", "")
                tool_input = content_item.get("input", {})
                if tool_name == "Skill" and skill_name in tool_input.get("skill", ""):
                    log.append(f"[{i}] assistant: Skill -> MATCH")
                    return True, log
                elif tool_name == "Read" and skill_name in tool_input.get("file_path", ""):
                    log.append(f"[{i}] assistant: Read -> MATCH")
                    return True, log
            if has_tool_use:
                log.append(f"[{i}] assistant: had tool_use but none matched -> return False")
                return False, log
            log.append(f"[{i}] assistant: content_types={content_types} -> no tool_use, keep waiting")

        elif event.get("type") == "result":
            log.append(f"[{i}] result: return triggered={triggered}")
            return triggered, log

    log.append(f"[end] exhausted all events, return triggered={triggered}")
    return triggered, log


def detect_bug4(events: list[dict], skill_name: str) -> tuple[bool, list[str]]:
    """Detection with Bug 4 reintroduced: no tool_use in assistant message -> return triggered."""
    log = []
    triggered = False
    pending_tool_name = None
    accumulated_json = ""

    for i, event in enumerate(events):
        if event.get("type") == "stream_event":
            se = event.get("event", {})
            se_type = se.get("type", "")

            if se_type == "content_block_start":
                cb = se.get("content_block", {})
                if cb.get("type") == "tool_use":
                    tool_name = cb.get("name", "")
                    if tool_name in ("Skill", "Read"):
                        pending_tool_name = tool_name
                        accumulated_json = ""
                        log.append(f"[{i}] stream/content_block_start: tool_use name={tool_name} -> TRACK")
                    else:
                        pending_tool_name = None
                        accumulated_json = ""
                        log.append(f"[{i}] stream/content_block_start: tool_use name={tool_name} -> RESET")

            elif se_type == "content_block_delta" and pending_tool_name:
                delta = se.get("delta", {})
                if delta.get("type") == "input_json_delta":
                    accumulated_json += delta.get("partial_json", "")
                    if skill_name in accumulated_json:
                        log.append(f"[{i}] stream/content_block_delta: MATCH")
                        return True, log

            elif se_type == "content_block_stop":
                if pending_tool_name:
                    if skill_name in accumulated_json:
                        log.append(f"[{i}] stream/content_block_stop: MATCH")
                        return True, log
                    pending_tool_name = None
                    accumulated_json = ""

            elif se_type == "message_stop":
                log.append(f"[{i}] stream/message_stop: return triggered={triggered}")
                return triggered, log

        elif event.get("type") == "assistant":
            message = event.get("message", {})
            content_types = [c.get("type") for c in message.get("content", [])]
            # BUG 4: iterate content, return triggered after loop regardless
            for content_item in message.get("content", []):
                if content_item.get("type") != "tool_use":
                    continue
                tool_name = content_item.get("name", "")
                tool_input = content_item.get("input", {})
                if tool_name == "Skill" and skill_name in tool_input.get("skill", ""):
                    log.append(f"[{i}] assistant: Skill -> MATCH")
                    return True, log
                elif tool_name == "Read" and skill_name in tool_input.get("file_path", ""):
                    log.append(f"[{i}] assistant: Read -> MATCH")
                    return True, log
                log.append(f"[{i}] assistant: tool_use {tool_name} -> no match, return triggered={triggered}")
                return triggered, log
            # BUG 4: no tool_use found -> return triggered (False) instead of continuing
            log.append(f"[{i}] assistant: content_types={content_types} -> BUG 4: return triggered={triggered}")
            return triggered, log

        elif event.get("type") == "result":
            log.append(f"[{i}] result: return triggered={triggered}")
            return triggered, log

    log.append(f"[end] exhausted all events, return triggered={triggered}")
    return triggered, log


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <log-file> <skill-name>")
        sys.exit(1)

    log_file = Path(sys.argv[1])
    skill_name = sys.argv[2]

    events = []
    for line in log_file.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue

    print(f"=== Log Summary ===")
    print(f"Total events: {len(events)}")
    type_counts: dict[str, int] = {}
    for e in events:
        t = e.get("type", "unknown")
        type_counts[t] = type_counts.get(t, 0) + 1
    for t, c in sorted(type_counts.items()):
        print(f"  {t}: {c}")

    print(f"\n=== Key Events (tool_use and assistant messages) ===")
    for i, e in enumerate(events):
        if e.get("type") == "stream_event":
            se = e.get("event", {})
            se_type = se.get("type", "")
            if se_type == "content_block_start":
                cb = se.get("content_block", {})
                if cb.get("type") == "tool_use":
                    print(f"  [{i}] stream_event/content_block_start: tool_use name={cb.get('name')}")
                elif cb.get("type") == "thinking":
                    print(f"  [{i}] stream_event/content_block_start: thinking")
            elif se_type == "message_stop":
                print(f"  [{i}] stream_event/message_stop")
        elif e.get("type") == "assistant":
            message = e.get("message", {})
            content_types = [c.get("type") for c in message.get("content", [])]
            tool_names = [
                c.get("name") for c in message.get("content", [])
                if c.get("type") == "tool_use"
            ]
            summary = f"content_types={content_types}"
            if tool_names:
                summary += f", tools={tool_names}"
            print(f"  [{i}] assistant: {summary}")
        elif e.get("type") == "result":
            print(f"  [{i}] result")

    print(f"\n{'='*60}")
    print(f"=== Detection Results (skill_name={skill_name!r}) ===")
    print(f"{'='*60}")

    for label, detector in [
        ("FIXED (current)", detect_fixed),
        ("BUG 3.5 (non-Skill tool -> return False)", detect_bug35),
        ("BUG 4 (no tool_use in message -> return False)", detect_bug4),
    ]:
        result, log = detector(events, skill_name)
        status = "TRIGGERED" if result else "NOT TRIGGERED"
        print(f"\n--- {label} ---")
        print(f"Result: {status}")
        print(f"Decision path:")
        for line in log:
            print(f"    {line}")


if __name__ == "__main__":
    main()
