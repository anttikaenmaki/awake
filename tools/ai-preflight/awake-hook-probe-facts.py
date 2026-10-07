#!/usr/bin/python3
# Copyright (C) 2026 Antti Käenmäki
"""Privacy-safe facts about one hook payload, for the Awake preflight probe.

awake-hook-probe.sh runs this with the hook's stdin (docs/plans/
agent-keep-awake.md, 10.1). It reads stdin with a time limit, so a payload
that never ends cannot hold the hook up, and prints only facts that carry
no user content:

- whether the read reached the end of stdin, how long that took, and the
  payload's length in bytes;
- the top-level keys in the order they were sent, each with its byte
  offset (an order-preserving walk over the JSON; when the payload is not
  valid JSON, a scan of the raw text for the known keys instead);
- the first content key and the id keys, with their offsets (W2);
- the values of short id and type fields only, and only when they look
  like ids or names (letters, digits and . _ : @ + -, at most 128);
- what W2's cut, W25's key sign and B-8's background pattern would find.

It never prints prompt text, tool input or output, file contents,
assistant messages, paths or e-mail addresses. Python 3.8 or later, the
standard library only.
"""

import json
import os
import re
import select
import sys
import time

READ_LIMIT_SECONDS = 0.8
KEEP_BYTES = 64 * 1024 * 1024
MAX_KEYS_SHOWN = 60

# W2's content keys: the hook cuts the payload at the first of these.
CONTENT_KEYS = (
    "prompt", "tool_input", "tool_response", "tool_output",
    "last_assistant_message", "text", "attachments", "prompt_response",
    "message", "details", "llm_request",
)
# Keys whose offsets W2 and W25 depend on.
ID_KEYS = (
    "session_id", "agent_id", "conversation_id", "generation_id",
    "child_conversation_id", "effort", "timestamp", "turn_id",
    "subagent_id", "parent_conversation_id", "prompt_id",
)
# Keys whose values are printed, when they are short and safe.
VALUE_KEYS = (
    "session_id", "agent_id", "conversation_id", "generation_id",
    "child_conversation_id", "subagent_id", "parent_conversation_id",
    "turn_id", "prompt_id", "tool_use_id", "tool_call_id",
    "hook_event_name", "notification_type", "tool_name", "agent_type",
    "subagent_type", "permission_mode", "source", "reason", "trigger",
    "status", "final_status", "failure_type", "composer_mode",
    "cursor_version", "stop_hook_active", "is_interrupt",
    "is_background_agent", "is_parallel_worker", "loop_count",
    "effort", "background_tasks", "session_crons", "error",
)
# The ids W2's patterns look for before the cut.
W2_ID_KEYS = ("session_id", "agent_id", "conversation_id", "tool_name")

SAFE_VALUE = re.compile(r"\A[A-Za-z0-9._:@+-]{0,128}\Z")
SAFE_ITEM = re.compile(r"\A[A-Za-z0-9._:@+-]{1,32}\Z")
WS = re.compile(r"[ \t\n\r]*")
ALL_KNOWN = tuple(dict.fromkeys(CONTENT_KEYS + ID_KEYS + VALUE_KEYS))
RAW_KEY = re.compile(
    r'(?<!\\)"(' + "|".join(re.escape(k) for k in ALL_KNOWN) + r')"[ \t\n\r]*:'
)
W2_CUT = re.compile(
    r'"(' + "|".join(re.escape(k) for k in CONTENT_KEYS) + r')"[ \t\n\r\v\f]*:'
)
W25_SIGN = re.compile(r'"(conversation_id|timestamp)"[ \t\n\r\v\f]*:')
BG_PATTERN = re.compile(r'"background_tasks"[ \t\n\r\v\f]*:[ \t\n\r\v\f]*\[[ \t\n\r\v\f]*\{')


def read_stdin():
    """Reads fd 0 until its end or the time limit.

    Returns (data, total_bytes, milliseconds, state), where state is
    "eof", "open" (the limit came first), "error" or "none".
    """
    start = time.monotonic()
    deadline = start + READ_LIMIT_SECONDS
    kept = []
    kept_bytes = 0
    total = 0
    state = "open"
    try:
        os.fstat(0)
    except OSError:
        return b"", 0, 0.0, "none"
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        try:
            ready, _, _ = select.select([0], [], [], remaining)
        except (OSError, ValueError):
            state = "error"
            break
        if not ready:
            break
        try:
            chunk = os.read(0, 1 << 16)
        except OSError:
            state = "error"
            break
        if not chunk:
            state = "eof"
            break
        total += len(chunk)
        if kept_bytes < KEEP_BYTES:
            piece = chunk[:KEEP_BYTES - kept_bytes]
            kept.append(piece)
            kept_bytes += len(piece)
    elapsed = (time.monotonic() - start) * 1000.0
    return b"".join(kept), total, elapsed, state


def walk_top_level(text):
    """Walks a JSON text's top level, keeping the order of its keys.

    The text is the payload decoded as Latin-1, so a character offset is a
    byte offset. Returns (kind, pairs): kind is "object", "object+trailing",
    "empty", "invalid" or the JSON type of a non-object; pairs is a list of
    (key, offset of the key's opening quote, value) for an object.
    """
    decoder = json.JSONDecoder()
    scanstring = json.decoder.scanstring
    i = WS.match(text, 0).end()
    if i >= len(text):
        return "empty", []
    if text[i] != "{":
        try:
            value, end = decoder.raw_decode(text, i)
        except ValueError:
            return "invalid", None
        if WS.match(text, end).end() != len(text):
            return "invalid", None
        kinds = {list: "array", str: "string", bool: "boolean",
                 int: "number", float: "number", type(None): "null"}
        return kinds.get(type(value), "other"), []
    pairs = []
    i = WS.match(text, i + 1).end()
    if text[i:i + 1] == "}":
        i += 1
    else:
        while True:
            if text[i:i + 1] != '"':
                return "invalid", None
            key_offset = i
            try:
                key, i = scanstring(text, i + 1)
            except ValueError:
                return "invalid", None
            i = WS.match(text, i).end()
            if text[i:i + 1] != ":":
                return "invalid", None
            i = WS.match(text, i + 1).end()
            try:
                value, i = decoder.raw_decode(text, i)
            except ValueError:
                return "invalid", None
            pairs.append((key, key_offset, value))
            i = WS.match(text, i).end()
            c = text[i:i + 1]
            if c == ",":
                i = WS.match(text, i + 1).end()
                continue
            if c == "}":
                i += 1
                break
            return "invalid", None
    if WS.match(text, i).end() != len(text):
        return "object+trailing", pairs
    return "object", pairs


def safe_name(key):
    """A key as it may be printed: keys are the agents' own field names,
    but anything odd is shown by its length only."""
    if SAFE_VALUE.match(key) and key:
        return key
    return "<key len=%d>" % len(key)


def show_value(key, value, event):
    """The printable form of one top-level value, or None to skip it."""
    if key == "error" and event != "StopFailure":
        return None
    if key == "effort":
        if isinstance(value, dict):
            level = value.get("level")
            if isinstance(level, str) and SAFE_VALUE.match(level):
                return "level:" + level
            return "<object>"
    if key == "background_tasks":
        if isinstance(value, list):
            items = []
            for item in value[:20]:
                if isinstance(item, dict):
                    kind = item.get("type")
                    status = item.get("status")
                    kind = kind if isinstance(kind, str) and SAFE_ITEM.match(kind) else "?"
                    status = status if isinstance(status, str) and SAFE_ITEM.match(status) else "?"
                    items.append(kind + "/" + status)
                else:
                    items.append("?")
            return "%d[%s]" % (len(value), ",".join(items))
    if key == "session_crons":
        if isinstance(value, list):
            return "%d" % len(value)
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        if SAFE_VALUE.match(value):
            return value if value else '""'
        return "<str len=%d>" % len(value)
    if isinstance(value, list):
        return "<list n=%d>" % len(value)
    if isinstance(value, dict):
        return "<object>"
    return "<other>"


def w2_facts(text):
    """What W2's cut, W25's key sign and B-8's pattern find in the raw text."""
    cut = W2_CUT.search(text)
    cut_at = cut.start() if cut else len(text)
    prefix = text[:cut_at]
    found = []
    for key in W2_ID_KEYS:
        m = re.search(
            r'"%s"[ \t\n\r\v\f]*:[ \t\n\r\v\f]*"([A-Za-z0-9._-]{1,128})"' % key, prefix)
        found.append("%s=%s" % (key, m.group(1) if m else "-"))
    sign = W25_SIGN.search(prefix)
    bg = BG_PATTERN.search(text)
    return (
        "w2 cut=%s %s w25-key-sign=%s bg-pattern=%s" % (
            ("%s@%d" % (cut.group(1), cut.start())) if cut else "none",
            " ".join(found),
            ("yes(%s@%d)" % (sign.group(1), sign.start())) if sign else "no",
            "yes" if bg else "no",
        ),
        cut.start() if cut else None,
    )


def facts(data, total, elapsed, state):
    lines = []
    if state == "eof":
        lines.append("stdin eof after %d ms, %d bytes" % (round(elapsed), total))
    elif state == "open":
        lines.append("stdin STILL OPEN after %d ms (read stopped there), %d bytes so far"
                     % (round(elapsed), total))
    elif state == "none":
        lines.append("stdin none (no file descriptor 0)")
    else:
        lines.append("stdin read error after %d ms, %d bytes" % (round(elapsed), total))
    if total > len(data):
        lines.append("note: only the first %d bytes were examined" % len(data))
    text = data.decode("latin-1")
    kind, pairs = walk_top_level(text)
    if kind in ("object", "object+trailing"):
        keys = ["%s@%d" % (safe_name(k), off) for k, off, _ in pairs]
        more = ""
        if len(keys) > MAX_KEYS_SHOWN:
            more = " (+%d more)" % (len(keys) - MAX_KEYS_SHOWN)
            keys = keys[:MAX_KEYS_SHOWN]
        lines.append("json %s, %d top-level keys: %s%s"
                     % (kind, len(pairs), " ".join(keys), more))
        first_content = None
        for k, off, _ in pairs:
            if k in CONTENT_KEYS:
                first_content = (k, off)
                break
        lines.append("content first=%s" % (
            "%s@%d" % first_content if first_content else "none"))
        before, after = [], []
        for k, off, _ in pairs:
            if k in ID_KEYS:
                if first_content is None or off < first_content[1]:
                    before.append("%s@%d" % (k, off))
                else:
                    after.append("%s@%d" % (k, off))
        lines.append("ids before-content: %s | after-content: %s" % (
            " ".join(before) or "-", " ".join(after) or "-"))
        event = ""
        for k, _, v in pairs:
            if k == "hook_event_name" and isinstance(v, str):
                event = v
        values = []
        for k, _, v in pairs:
            if k in VALUE_KEYS:
                shown = show_value(k, v, event)
                if shown is not None:
                    values.append("%s=%s" % (k, shown))
        lines.append("values %s" % (" ".join(values) or "-"))
        w2_line, cut_at = w2_facts(text)
        if first_content and cut_at is not None and cut_at != first_content[1]:
            w2_line += " (cut is not at the top-level content key)"
        lines.append(w2_line)
    elif kind == "empty":
        lines.append("json empty payload")
    elif kind == "invalid":
        found = {}
        for m in RAW_KEY.finditer(text):
            found.setdefault(m.group(1), m.start())
        shown = sorted(found.items(), key=lambda item: item[1])
        lines.append("json invalid; raw scan of known keys (any depth): %s" % (
            " ".join("%s@%d" % item for item in shown) or "none"))
        lines.append(w2_facts(text)[0])
    else:
        lines.append("json top level is %s, not an object" % kind)
    return lines


AGENT_FIELDS = ("kind", "pid", "status", "waitingFor", "state", "sessionId", "id")


def agents_summary(raw):
    """claude agents --json, without cwd and name: per session only its
    kind, pid, status, waitingFor, state and ids (10.2's last look, W21)."""
    try:
        data = json.loads(raw.decode("utf-8", "replace"))
    except ValueError:
        return "not JSON (%d bytes)" % len(raw)
    if not isinstance(data, list):
        return "not a JSON array"
    parts = []
    for item in data[:50]:
        if not isinstance(item, dict):
            parts.append("?")
            continue
        fields = []
        for key in AGENT_FIELDS:
            if key in item:
                value = item[key]
                if isinstance(value, str) and not SAFE_VALUE.match(value.replace(" ", "_")):
                    value = "<str len=%d>" % len(value)
                elif isinstance(value, str):
                    value = value.replace(" ", "_")
                fields.append("%s=%s" % (key, value))
        parts.append("{%s}" % " ".join(fields))
    return "%d sessions: %s" % (len(data), " ".join(parts) or "-")


SAFE_ERROR = re.compile(r"[^A-Za-z0-9 ._:'()=,/-]")


def last_look(claude, pre=()):
    """Runs CLAUDE [PRE...] agents --json with this process's environment
    (PRE: global options, which go before the subcommand), in a new session
    (as Awake's watcher would run it, detached), and prints how long it took
    and the summary. On a non-zero exit, also the first line of its error
    output (an option it rejected, say), with odd characters replaced."""
    import subprocess
    try:
        os.setsid()
    except OSError:
        pass
    start = time.monotonic()
    try:
        res = subprocess.run([claude] + list(pre) + ["agents", "--json"],
                             stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
    except subprocess.TimeoutExpired:
        return "timed out after 10 s"
    except OSError as exc:
        return "could not run: %s" % exc.strerror
    ms = (time.monotonic() - start) * 1000.0
    out = "exit %d after %d ms, %s" % (res.returncode, round(ms), agents_summary(res.stdout))
    if res.returncode != 0:
        lines = [l for l in res.stderr.decode("utf-8", "replace").splitlines() if l.strip()]
        if lines:
            out += "; error output: " + SAFE_ERROR.sub("?", lines[0].strip())[:160]
    return out


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--agents-json":
        data, _, _, _ = read_stdin()
        sys.stdout.write(agents_summary(data) + "\n")
        return 0
    if len(sys.argv) >= 3 and sys.argv[1] == "--last-look":
        sys.stdout.write(last_look(sys.argv[2], sys.argv[3:]) + "\n")
        return 0
    data, total, elapsed, state = read_stdin()
    try:
        out = facts(data, total, elapsed, state)
    except Exception as exc:  # never fail the hook; say what broke
        out = ["facts error: %s" % type(exc).__name__]
    sys.stdout.write("\n".join(out) + "\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
