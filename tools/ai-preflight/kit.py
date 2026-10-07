#!/usr/bin/python3
# Copyright (C) 2026 Antti Käenmäki
"""The JSON side of the Awake preflight kit (docs/plans/agent-keep-awake.md,
section 10). probe.sh and collect.sh run it with /usr/bin/python3 -I.

It installs the probe's handlers into each agent's user-level hook file
exactly as K.3 lists Awake's own (same events, matchers, async flags,
timeouts and position rules), backs each file up first, and removes exactly
its own entries again. It follows K5's rules for writing: the file must
parse and have the documented shape, symlinks are written through, the mode
is kept, a file that changed between the read and the write is refused, and
nothing is written when nothing changes. It never edits Codex's config.toml
(where Codex keeps its trust) or any project file.

Python 3.8 or later, the standard library only.
"""

import argparse
import copy
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

PROBE_NAME = "awake-hook-probe.sh"
FACTS_NAME = "awake-hook-probe-facts.py"
STOP_BLOCK_NAME = "awake-stop-block.sh"
STOP_BLOCK_TIMEOUT = 150
SPACE_DIR = "probe with space"
MARKER = ".awake-preflight"
GEMINI_EXT_NAME = "awake-probe"
AGENTS = ("claude", "cursor", "codex", "gemini")
AGENT_NAMES = {"claude": "Claude Code", "cursor": "Cursor", "codex": "Codex",
               "gemini": "Gemini CLI"}


class Refusal(Exception):
    """The kit refuses to go on; the message says why. Nothing was changed."""


class NotFound(Refusal):
    """The agent is not installed on this Mac."""


class Unfinished(Refusal):
    """The kit did its part, but something it may not touch is left; the
    message says what and how to finish."""


def now_stamp():
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")


def now_text():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def sh_quote(text):
    """Single-quotes a word for sh, bash, zsh and fish, as awake's sh_quote."""
    return "'" + text.replace("'", "'\\''") + "'"


def shell_path(path, home):
    """path as a shell word to paste: under the home folder as ~/..., which
    the shells expand (also after VAR=), and quoted only when needed."""
    rest = None
    if home and path == home:
        return "~"
    if home and path.startswith(home.rstrip("/") + "/"):
        rest = path[len(home.rstrip("/")) + 1:]
    word = rest if rest is not None else path
    if not re.match(r"\A[A-Za-z0-9._/+-]+\Z", word):
        word = sh_quote(word)
    return ("~/" + word) if rest is not None else word


def tilde(text, home):
    if home and isinstance(text, str):
        return text.replace(home, "~")
    return text


# ---------------------------------------------------------------- the specs

class Spec:
    """One probe handler: where it goes and what it looks like."""

    def __init__(self, event, matcher, label, is_async=False, timeout=None, name=None):
        self.event = event
        self.matcher = matcher
        self.label = label
        self.is_async = is_async
        self.timeout = timeout
        self.name = name


# K.3.1: Claude Code, 13 handlers.
CLAUDE_SPECS = [
    Spec("UserPromptSubmit", None, "UserPromptSubmit", timeout=10),
    Spec("SessionStart", "clear", "SessionStart.clear", timeout=10),
    Spec("Stop", None, "Stop", timeout=10),
    Spec("StopFailure", None, "StopFailure", timeout=10),
    Spec("SessionEnd", None, "SessionEnd"),
    Spec("Notification", "idle_prompt", "Notification.idle_prompt", timeout=10),
    Spec("SubagentStart", None, "SubagentStart", timeout=10),
    Spec("SubagentStop", None, "SubagentStop", timeout=10),
    Spec("PermissionRequest", None, "PermissionRequest", timeout=10),
    Spec("PreToolUse", "AskUserQuestion|ExitPlanMode", "PreToolUse.waiting", timeout=10),
    Spec("PreToolUse", None, "PreToolUse", is_async=True),
    Spec("PostToolUse", None, "PostToolUse", is_async=True),
    Spec("PostToolUseFailure", None, "PostToolUseFailure", is_async=True),
]
# K.3.2: Codex, 10 handlers, each in a group of its own at the end.
CODEX_SPECS = [
    Spec("UserPromptSubmit", None, "UserPromptSubmit", timeout=10),
    Spec("Stop", None, "Stop", timeout=10),
    Spec("Interrupt", None, "Interrupt"),
    Spec("SessionEnd", None, "SessionEnd"),
    Spec("SubagentStart", None, "SubagentStart", timeout=10),
    Spec("SubagentStop", None, "SubagentStop", timeout=10),
    Spec("PermissionRequest", None, "PermissionRequest", timeout=10),
    Spec("PreToolUse", "request_user_input", "PreToolUse.request_user_input", timeout=10),
    Spec("PreToolUse", None, "PreToolUse", is_async=True),
    Spec("PostToolUse", None, "PostToolUse", is_async=True),
]
# K.3.3: Cursor, 7 handlers, flat entries at the end.
CURSOR_SPECS = [
    Spec("beforeSubmitPrompt", None, "beforeSubmitPrompt", timeout=10),
    Spec("afterAgentThought", None, "afterAgentThought", timeout=10),
    Spec("preToolUse", None, "preToolUse", timeout=10),
    Spec("postToolUse", None, "postToolUse", timeout=10),
    Spec("postToolUseFailure", None, "postToolUseFailure", timeout=10),
    Spec("stop", None, "stop", timeout=10),
    Spec("sessionEnd", None, "sessionEnd", timeout=10),
]
# Not in K.3.3: an observation-only handler that 10.2 (t) needs, to see
# whether subagentStop fires with child_conversation_id. Only with --extra.
CURSOR_EXTRA_SPECS = [
    Spec("subagentStop", None, "subagentStop", timeout=10),
]
# K.3.4: Gemini CLI, 6 handlers, timeouts in milliseconds.
GEMINI_SPECS = [
    Spec("BeforeAgent", "", "BeforeAgent", timeout=10000, name="awake-probe-turn-start"),
    Spec("BeforeTool", "", "BeforeTool", timeout=10000, name="awake-probe-tool-start"),
    Spec("AfterTool", "", "AfterTool", timeout=10000, name="awake-probe-working"),
    Spec("Notification", "", "Notification", timeout=10000, name="awake-probe-waiting"),
    Spec("AfterAgent", "", "AfterAgent", timeout=10000, name="awake-probe-turn-end"),
    Spec("SessionEnd", "", "SessionEnd", timeout=10000, name="awake-probe-session-end"),
]
# 10.1: one handler per agent runs the copy at a path with a space.
SPACE_LABEL = {"claude": "UserPromptSubmit", "codex": "UserPromptSubmit",
               "cursor": "beforeSubmitPrompt", "gemini": "BeforeAgent"}

KIT_COMMAND = re.compile(
    r"\A'((?:[^']|'\\'')*)' (claude|codex|cursor|gemini) ([A-Za-z0-9._-]+)"
    r" >/dev/null 2>&1; exit 0\Z")


def specs_for(agent, extra=False):
    if agent == "claude":
        return CLAUDE_SPECS
    if agent == "codex":
        return CODEX_SPECS
    if agent == "cursor":
        return CURSOR_SPECS + (CURSOR_EXTRA_SPECS if extra else [])
    return GEMINI_SPECS


def snake(event):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", event).lower()


# -------------------------------------------------------------------- the kit

class Kit:
    def __init__(self, args):
        self.home = os.path.expanduser("~")
        self.dir = os.path.abspath(args.dir)
        self.src = os.path.abspath(args.kit_src)
        self.python = args.python
        self.main = os.path.join(self.dir, PROBE_NAME)
        self.space = os.path.join(self.dir, SPACE_DIR, PROBE_NAME)
        self.stop_block = os.path.join(self.dir, STOP_BLOCK_NAME)
        self.logs = os.path.join(self.dir, "logs")
        self.state = os.path.join(self.dir, "state")
        self.backups = os.path.join(self.dir, "backups")
        self.gemini_ext = os.path.join(self.dir, "gemini-extension")
        self.out = sys.stdout

    def say(self, text=""):
        self.out.write(tilde(text, self.home) + "\n")

    # -- paths of the agents' files

    def claude_dir(self):
        return os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(self.home, ".claude")

    def codex_dir(self):
        return os.environ.get("CODEX_HOME") or os.path.join(self.home, ".codex")

    def gemini_home(self):
        return os.path.join(os.environ.get("GEMINI_CLI_HOME") or self.home, ".gemini")

    def agent_file(self, agent):
        if agent == "claude":
            return os.path.join(self.claude_dir(), "settings.json")
        if agent == "codex":
            return os.path.join(self.codex_dir(), "hooks.json")
        if agent == "cursor":
            return os.path.join(self.home, ".cursor", "hooks.json")
        return os.path.join(self.gemini_ext, "hooks", "hooks.json")

    # -- the probe's commands

    def probe_path(self, agent, label):
        return self.space if SPACE_LABEL.get(agent) == label else self.main

    def command(self, path, agent, label):
        return "%s %s %s >/dev/null 2>&1; exit 0" % (sh_quote(path), agent, label)

    def parse_command(self, handler):
        """(path, agent, label) when handler is one of the kit's, else None.

        A handler is the kit's only when its command is exactly K2's form
        with the path of one of the two installed probe copies."""
        if not isinstance(handler, dict):
            return None
        cmd = handler.get("command")
        if not isinstance(cmd, str):
            return None
        m = KIT_COMMAND.match(cmd)
        if not m:
            return None
        path = m.group(1).replace("'\\''", "'")
        if path not in (self.main, self.space):
            return None
        return path, m.group(2), m.group(3)

    def foreign_probe(self, handler):
        """The probe path of a handler in K2's form that runs a probe copy
        outside this preflight folder (an install with another
        AWAKE_PREFLIGHT_DIR, or a folder moved since), else None."""
        if not isinstance(handler, dict) or not isinstance(handler.get("command"), str):
            return None
        m = KIT_COMMAND.match(handler["command"])
        if not m:
            return None
        path = m.group(1).replace("'\\''", "'")
        if path in (self.main, self.space) or os.path.basename(path) != PROBE_NAME:
            return None
        return path

    def is_stop_block(self, handler):
        """True for the 10.3 (c) Stop handler that stop-block on adds."""
        return (isinstance(handler, dict)
                and handler.get("command") == sh_quote(self.stop_block))

    def stop_block_handler(self):
        return {"type": "command", "command": sh_quote(self.stop_block),
                "timeout": STOP_BLOCK_TIMEOUT}

    def handler(self, agent, spec, path=None):
        cmd = self.command(path or self.probe_path(agent, spec.label), agent, spec.label)
        if agent == "cursor":
            return {"command": cmd, "timeout": spec.timeout}
        if agent == "gemini":
            return {"type": "command", "command": cmd, "name": spec.name,
                    "timeout": spec.timeout}
        h = {"type": "command", "command": cmd}
        if spec.is_async:
            h["async"] = True
        elif spec.timeout is not None:
            h["timeout"] = spec.timeout
        return h

    # -- the probe files and the run log

    def ensure_dirs(self):
        for d in (self.dir, self.logs, self.state, self.backups,
                  os.path.join(self.dir, SPACE_DIR)):
            os.makedirs(d, mode=0o700, exist_ok=True)
        marker = os.path.join(self.dir, MARKER)
        if not os.path.exists(marker):
            with open(marker, "w") as f:
                f.write("Awake preflight kit folder; tools/ai-preflight/probe.sh purge deletes it.\n")

    def probe_text(self, name=PROBE_NAME):
        with open(os.path.join(self.src, name), encoding="utf-8") as f:
            text = f.read()
        keys = (("PROBE_DIR", self.dir), ("PROBE_PYTHON", self.python),
                ("PROBE_MAIN", self.main))
        if name != PROBE_NAME:
            keys = keys[:1]
        for key, value in keys:
            line = "%s='@@%s@@'" % (key, key)
            if line not in text:
                raise Refusal("the probe template lacks the line %s" % line)
            text = text.replace(line, "%s=%s" % (key, sh_quote(value)))
        return text

    def ensure_probe(self):
        """Installs or updates both probe copies and starts a run log."""
        if "\n" in self.dir or "$" in self.dir or "`" in self.dir:
            raise Refusal("the preflight folder %s has a character the agents' shells "
                          "would expand ($, ` or a newline); set AWAKE_PREFLIGHT_DIR" % self.dir)
        self.ensure_dirs()
        probe = self.probe_text().encode("utf-8")
        with open(os.path.join(self.src, FACTS_NAME), "rb") as f:
            facts = f.read()
        for folder in (self.dir, os.path.join(self.dir, SPACE_DIR)):
            for name, data, mode in ((PROBE_NAME, probe, 0o755), (FACTS_NAME, facts, 0o644)):
                path = os.path.join(folder, name)
                try:
                    with open(path, "rb") as f:
                        if f.read() == data and (os.stat(path).st_mode & 0o777) == mode:
                            continue
                except OSError:
                    pass
                fd, tmp = tempfile.mkstemp(prefix="." + name + ".", dir=folder)
                with os.fdopen(fd, "wb") as f:
                    f.write(data)
                os.chmod(tmp, mode)
                os.replace(tmp, path)
        if not os.path.lexists(os.path.join(self.logs, "current.log")):
            self.new_run("start")

    def new_run(self, name):
        self.ensure_dirs()
        name = re.sub(r"[^A-Za-z0-9._-]+", "-", name or "").strip("-")[:40]
        base = "run-%s%s" % (now_stamp(), ("-" + name) if name else "")
        path = os.path.join(self.logs, base + ".log")
        n = 2
        while os.path.exists(path):
            path = os.path.join(self.logs, "%s-%d.log" % (base, n))
            n += 1
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write("# Awake preflight probe log %s, started %s\n"
                    "# One block per hook run: a START line, then the details under its pid.\n"
                    "# No prompt text, tool input or output, file contents or messages.\n"
                    % (os.path.basename(path), now_text()))
        link = os.path.join(self.logs, "current.log")
        tmp = os.path.join(self.logs, ".current.%d" % os.getpid())
        if os.path.lexists(tmp):
            os.unlink(tmp)
        os.symlink(os.path.basename(path), tmp)
        os.replace(tmp, link)
        return path

    # -- manifests and backups

    def manifest_path(self, agent):
        return os.path.join(self.state, agent + ".json")

    def load_manifest(self, agent):
        try:
            with open(self.manifest_path(agent), encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            return None

    def save_manifest(self, agent, data):
        self.ensure_dirs()
        path = self.manifest_path(agent)
        fd, tmp = tempfile.mkstemp(prefix=".manifest.", dir=self.state)
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.replace(tmp, path)

    def archive_manifest(self, agent):
        path = self.manifest_path(agent)
        if os.path.exists(path):
            os.replace(path, os.path.join(self.state, "%s.restored-%s.json" % (agent, now_stamp())))

    def backup(self, agent, snap):
        """Copies the bytes read to a new, timestamped file; never overwrites."""
        self.ensure_dirs()
        base = os.path.join(self.backups, "%s-%s-%s" % (
            agent, os.path.basename(snap.path), now_stamp()))
        path = base + ".bak"
        n = 2
        while True:
            try:
                fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                break
            except FileExistsError:
                path = "%s-%d.bak" % (base, n)
                n += 1
        with os.fdopen(fd, "wb") as f:
            f.write(snap.data)
        return path


# ------------------------------------------------------------ reading, writing

class Snapshot:
    """A file as read: the path given, the file the path resolves to, and
    the bytes (None when it does not exist)."""

    def __init__(self, path):
        self.path = path
        if os.path.islink(path) and not os.path.exists(path):
            raise Refusal("%s is a symlink to a missing file; fix the link first" % path)
        self.target = os.path.realpath(path)
        self.is_link = os.path.islink(path)
        if os.path.isdir(self.target):
            raise Refusal("%s is a folder, not a file" % path)
        try:
            with open(self.target, "rb") as f:
                self.data = f.read()
            self.mode = os.stat(self.target).st_mode & 0o7777
        except FileNotFoundError:
            self.data = None
            self.mode = None
        except OSError as exc:
            raise Refusal("cannot read %s: %s" % (path, exc.strerror))

    @property
    def exists(self):
        return self.data is not None

    def check_writable(self):
        folder = os.path.dirname(self.target)
        if self.exists and (not os.access(self.target, os.W_OK) or not self.mode & 0o200):
            raise Refusal("%s is read-only (mode %o); the kit does not override that. "
                          "Make it writable, or add the handlers by hand (probe.sh print)"
                          % (self.path, self.mode))
        if not os.access(folder, os.W_OK | os.X_OK):
            raise Refusal("cannot write in %s, where %s is" % (folder, self.path))


def reject_constant(name):
    raise ValueError("non-standard JSON constant " + name)


def unique_pairs(pairs):
    seen = set()
    for key, _ in pairs:
        if key in seen:
            raise ValueError("duplicate key %r" % key)
        seen.add(key)
    return dict(pairs)


def parse_json(snap):
    """The file's JSON object; an empty file reads as {}."""
    if not snap.exists:
        return {}
    try:
        text = snap.data.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise Refusal("%s is not UTF-8 text" % snap.path)
    if not text.strip():
        return {}
    try:
        doc = json.loads(text, object_pairs_hook=unique_pairs, parse_constant=reject_constant)
    except ValueError as exc:
        raise Refusal("%s is not plain JSON (%s); the kit edits only files it can parse. "
                      "Comments and trailing commas are not plain JSON. Use probe.sh print "
                      "to add the handlers by hand" % (snap.path, exc))
    if not isinstance(doc, dict):
        raise Refusal("%s does not hold a JSON object at the top level" % snap.path)
    try:
        dumps(doc)
    except Refusal:
        raise Refusal("%s holds a lone surrogate escape (\\ud800 to \\udfff), which the kit "
                      "cannot write back as UTF-8; edit the file by hand (probe.sh print shows "
                      "the probe's handlers)" % snap.path)
    return doc


def dumps(doc):
    try:
        return (json.dumps(doc, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    except UnicodeEncodeError:
        raise Refusal("the JSON holds a lone surrogate escape (\\ud800 to \\udfff), which the "
                      "kit cannot write back as UTF-8; edit the file by hand (probe.sh print "
                      "shows the probe's handlers)")


def run_test_seam(target):
    """Lets the tests change the file between the read and the compare (K5's
    ai_hooks_before_compare). Only with AWAKE_PREFLIGHT_TEST=1."""
    cmd = os.environ.get("AWAKE_PREFLIGHT_TEST_BEFORE_COMPARE")
    if cmd and os.environ.get("AWAKE_PREFLIGHT_TEST") == "1":
        env = dict(os.environ, TARGET=target)
        subprocess.run(["/bin/sh", "-c", cmd], env=env, check=False)


def safe_write(snap, new_bytes):
    """Writes new_bytes over the file read in snap, or deletes it when
    new_bytes is None: through a symlink, with the file's mode, and only if
    the file still holds what was read."""
    folder = os.path.dirname(snap.target)
    tmp = None
    if new_bytes is not None:
        fd, tmp = tempfile.mkstemp(prefix="." + os.path.basename(snap.target) + ".preflight-",
                                   dir=folder)
        try:
            with os.fdopen(fd, "wb") as f:
                f.write(new_bytes)
                f.flush()
                os.fsync(f.fileno())
            os.chmod(tmp, snap.mode if snap.mode is not None else 0o600)
        except BaseException:
            os.unlink(tmp)
            raise
    try:
        run_test_seam(snap.target)
        try:
            with open(snap.target, "rb") as f:
                current = f.read()
        except FileNotFoundError:
            current = None
        if current != snap.data:
            raise Refusal("%s changed while the kit was editing it (another program wrote "
                          "it); nothing was written. Run the command again" % snap.path)
        if new_bytes is None:
            os.unlink(snap.target)
        elif snap.data is None:
            try:
                os.link(tmp, snap.target)
            except FileExistsError:
                raise Refusal("%s appeared while the kit was creating it; nothing was "
                              "written. Run the command again" % snap.path)
        else:
            os.replace(tmp, snap.target)
            tmp = None
    finally:
        if tmp is not None and os.path.exists(tmp):
            os.unlink(tmp)


# ------------------------------------------------------- the shape of the files

def check_nested(doc, path, codex):
    """K5's shape for Claude Code and Codex: event -> groups -> hooks."""
    if codex:
        extra = [k for k in doc if k not in ("description", "hooks")]
        if extra:
            raise Refusal("%s has top-level keys Codex does not allow (%s); Codex would "
                          "skip the whole file" % (path, ", ".join(sorted(extra))))
    hooks = doc.get("hooks", {})
    if not isinstance(hooks, dict):
        raise Refusal('%s: "hooks" is not an object' % path)
    for event, groups in hooks.items():
        if not isinstance(groups, list):
            raise Refusal('%s: hooks.%s is not a list of groups' % (path, event))
        for gi, group in enumerate(groups):
            if not isinstance(group, dict):
                raise Refusal("%s: hooks.%s[%d] is not an object" % (path, event, gi))
            if "matcher" in group and not isinstance(group["matcher"], (str, type(None))):
                raise Refusal("%s: hooks.%s[%d].matcher is not a string" % (path, event, gi))
            inner = group.get("hooks", [])
            if not isinstance(inner, list):
                raise Refusal("%s: hooks.%s[%d].hooks is not a list" % (path, event, gi))
            for hi, h in enumerate(inner):
                if not isinstance(h, dict):
                    raise Refusal("%s: hooks.%s[%d].hooks[%d] is not an object"
                                  % (path, event, gi, hi))


def check_cursor(doc, path, require_version=True):
    """K5's shape for Cursor: version, and hooks -> event -> entries."""
    if "version" in doc:
        v = doc["version"]
        if not isinstance(v, int) or isinstance(v, bool) or v < 1:
            raise Refusal("%s: version is not a positive whole number" % path)
    elif "hooks" in doc and require_version:
        raise Refusal('%s has "hooks" but no "version"; Cursor requires it. '
                      'Add "version": 1 by hand first' % path)
    hooks = doc.get("hooks", {})
    if not isinstance(hooks, dict):
        raise Refusal('%s: "hooks" is not an object' % path)
    for event, entries in hooks.items():
        if not isinstance(entries, list):
            raise Refusal("%s: hooks.%s is not a list" % (path, event))
        for i, e in enumerate(entries):
            if not isinstance(e, dict):
                raise Refusal("%s: hooks.%s[%d] is not an object" % (path, event, i))


def matcher_key(value):
    """Claude Code reads a missing matcher and "" alike."""
    return "" if value is None else value


# ---------------------------------------------------------- adding, removing

def remove_kit(kit, doc, agent, keep=None, codex=False, flat=False, stop_block=False):
    """Removes the kit's handlers from doc (in place), except those whose
    label is in keep (a dict label -> (event, group, handler)); with
    stop_block, also the 10.3 (c) Stop handler.

    Groups and events left empty by the removal are removed, except a Codex
    group that is not last in its array, which stays as {"hooks": []} so
    that the user's later groups keep their positions and their trust (K5).
    Returns (removed count, whether the top "hooks" key was emptied)."""
    keep = keep or {}
    hooks = doc.get("hooks")
    if not isinstance(hooks, dict):
        return 0, False
    removed = 0
    emptied_events = []
    for event in list(hooks):
        groups = hooks[event]
        touched = False
        if flat:
            new_entries = []
            for i, e in enumerate(groups):
                k = kit.parse_command(e)
                if k and keep.get(k[2]) != (event, i, None):
                    removed += 1
                    touched = True
                    continue
                new_entries.append(e)
            hooks[event] = new_entries
            if touched and not new_entries:
                emptied_events.append(event)
            continue
        emptied = []
        for gi, group in enumerate(groups):
            inner = group.get("hooks")
            if not isinstance(inner, list):
                continue
            new_inner = []
            for hi, h in enumerate(inner):
                k = kit.parse_command(h)
                if (k and keep.get(k[2]) != (event, gi, hi)) or (
                        stop_block and kit.is_stop_block(h)):
                    removed += 1
                    touched = True
                    continue
                new_inner.append(h)
            if len(new_inner) != len(inner):
                group["hooks"] = new_inner
                if not new_inner:
                    emptied.append(gi)
        if not emptied:
            continue
        if codex:
            emptied_set = set(emptied)
            while groups and (len(groups) - 1) in emptied_set:
                emptied_set.discard(len(groups) - 1)
                groups.pop()
            for gi in emptied_set:
                groups[gi] = {"hooks": []}
        else:
            hooks[event] = [g for gi, g in enumerate(groups) if gi not in set(emptied)]
        if touched and not hooks[event]:
            emptied_events.append(event)
    for event in emptied_events:
        del hooks[event]
    return removed, bool(emptied_events) and not hooks


def find_kit(kit, doc, agent, specs, flat=False):
    """Maps each spec label to the position of the kit's handler that
    already matches it in place (same event and matcher); the first one
    wins, and any other kit handler is left for remove_kit."""
    wanted = {s.label: s for s in specs}
    found = {}
    hooks = doc.get("hooks")
    if not isinstance(hooks, dict):
        return found
    for event, groups in hooks.items():
        if flat:
            for i, e in enumerate(groups):
                k = kit.parse_command(e)
                if not k or k[1] != agent:
                    continue
                spec = wanted.get(k[2])
                if spec and spec.event == event and k[2] not in found:
                    found[k[2]] = (event, i, None)
            continue
        for gi, group in enumerate(groups):
            for hi, h in enumerate(group.get("hooks", [])):
                k = kit.parse_command(h)
                if not k or k[1] != agent:
                    continue
                spec = wanted.get(k[2])
                if (spec and spec.event == event and k[2] not in found
                        and matcher_key(group.get("matcher")) == matcher_key(spec.matcher)):
                    found[k[2]] = (event, gi, hi)
    return found


def plan_install(kit, doc, agent, specs):
    """Returns (new doc, list of what changed). K5: a kit handler already in
    place is updated in place; a missing one is added to a group with the
    same matcher or a new group at the end (Claude Code), always a new group
    at the end (Codex), or an entry at the end (Cursor)."""
    new = copy.deepcopy(doc)
    flat = agent == "cursor"
    codex = agent == "codex"
    notes = []
    if flat and "version" not in new:
        new = dict([("version", 1)] + list(new.items()))
        notes.append('set "version": 1')
    if "hooks" not in new:
        new["hooks"] = {}
    found = find_kit(kit, new, agent, specs, flat=flat)
    removed, _ = remove_kit(kit, new, agent, keep=found, codex=codex, flat=flat)
    if removed:
        notes.append("removed %d old probe handler(s)" % removed)
    # Positions may have moved for Claude Code (an emptied group removed);
    # look again.
    found = find_kit(kit, new, agent, specs, flat=flat)
    hooks = new["hooks"]
    for spec in specs:
        want = kit.handler(agent, spec)
        if spec.label in found:
            event, gi, hi = found[spec.label]
            if flat:
                if hooks[event][gi] != want:
                    hooks[event][gi] = want
                    notes.append("updated %s" % spec.label)
            elif hooks[event][gi]["hooks"][hi] != want:
                hooks[event][gi]["hooks"][hi] = want
                notes.append("updated %s" % spec.label)
            continue
        lst = hooks.setdefault(spec.event, [])
        if flat:
            lst.append(want)
        elif codex:
            group = {"hooks": [want]} if spec.matcher is None else {
                "matcher": spec.matcher, "hooks": [want]}
            lst.append(group)
        else:
            # A group with the same matcher and handlers of its own (K5); a
            # group without a "hooks" list, or with an empty one, is left as
            # it is, so that restore never has to remove or reshape it.
            target = None
            for group in lst:
                if (matcher_key(group.get("matcher")) == matcher_key(spec.matcher)
                        and isinstance(group.get("hooks"), list) and group["hooks"]):
                    target = group
                    break
            if target is None:
                target = {"hooks": []} if spec.matcher is None else {
                    "matcher": spec.matcher, "hooks": []}
                lst.append(target)
            target["hooks"].append(want)
        notes.append("added %s" % spec.label)
    return new, notes


def strip_variants(kit, doc, agent):
    """The file without the kit's handlers: the minimal form (empty
    containers removed) and, as a second candidate, the same with an empty
    "hooks" object kept, in case the original had one."""
    flat = agent == "cursor"
    codex = agent == "codex"
    a = copy.deepcopy(doc)
    removed, emptied_top = remove_kit(kit, a, agent, codex=codex, flat=flat,
                                      stop_block=agent == "claude")
    b = copy.deepcopy(a)
    if "hooks" in a and a["hooks"] == {}:
        del a["hooks"]
    if "hooks" not in b and emptied_top:
        b["hooks"] = {}
    return removed, a, b


def foreign_dirs(kit, doc, flat=False):
    """{preflight folder: count} for the probe handlers of other preflight
    folders in doc."""
    found = {}
    hooks = doc.get("hooks")
    if not isinstance(hooks, dict):
        return found
    for groups in hooks.values():
        if not isinstance(groups, list):
            continue
        handlers = groups if flat else [
            h for g in groups if isinstance(g, dict) and isinstance(g.get("hooks"), list)
            for h in g["hooks"]]
        for h in handlers:
            path = kit.foreign_probe(h)
            if path:
                folder = os.path.dirname(path)
                if os.path.basename(folder) == SPACE_DIR:
                    folder = os.path.dirname(folder)
                found[folder] = found.get(folder, 0) + 1
    return found


def foreign_note(kit, found, agent):
    return "; ".join(
        "%d probe handler(s) from another preflight folder, %s: restore them with "
        "AWAKE_PREFLIGHT_DIR=%s probe.sh restore %s" % (n, folder, shell_path(folder, kit.home),
                                                         agent)
        for folder, n in sorted(found.items()))


def prune_empty(doc, codex=False, flat=False):
    """doc with empty containers dropped, for comparing a file with its
    backup: groups with no or an empty "hooks" list (for Codex only those at
    the end of their array, as the others hold later groups' positions),
    empty event lists, and an empty "hooks" object."""
    d = copy.deepcopy(doc)
    hooks = d.get("hooks")
    if not isinstance(hooks, dict):
        return d
    for event in list(hooks):
        groups = hooks[event]
        if not isinstance(groups, list):
            continue
        if not flat:
            def empty(g):
                return isinstance(g, dict) and not g.get("hooks")
            if codex:
                while groups and empty(groups[-1]):
                    groups.pop()
            else:
                groups[:] = [g for g in groups if not empty(g)]
        if not groups:
            del hooks[event]
    if not hooks:
        del d["hooks"]
    return d


def count_kit(kit, doc, agent, flat=False):
    found = []
    hooks = doc.get("hooks")
    if not isinstance(hooks, dict):
        return found
    for event, groups in hooks.items():
        if not isinstance(groups, list):
            continue
        if flat:
            for i, e in enumerate(groups):
                k = kit.parse_command(e)
                if k:
                    found.append((event, i, None, None, e, k))
            continue
        for gi, group in enumerate(groups):
            if not isinstance(group, dict) or not isinstance(group.get("hooks", []), list):
                continue
            for hi, h in enumerate(group.get("hooks", [])):
                k = kit.parse_command(h)
                if k:
                    found.append((event, gi, hi, group.get("matcher"), h, k))
    return found


# ----------------------------------------------------------- per-agent checks

def codex_toml_lines(kit):
    path = os.path.join(kit.codex_dir(), "config.toml")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return path, f.read().splitlines()
    except OSError:
        return path, []


INLINE_HOOKS = re.compile(r"^\s*\[\[\s*hooks\.(?!state\b)[A-Za-z]")
TRUST_HEADER = re.compile(r'^\s*\[hooks\.state\."(.+)"\]\s*$')
TABLE_HEADER = re.compile(r"^\s*\[")


def codex_trust(kit):
    """{key: {"trusted_hash": ..., "enabled": ...}} from config.toml, read
    line by line (the kit never parses or edits TOML)."""
    _, lines = codex_toml_lines(kit)
    entries = {}
    current = None
    for line in lines:
        m = TRUST_HEADER.match(line)
        if m:
            current = entries.setdefault(m.group(1), {})
            continue
        if TABLE_HEADER.match(line):
            current = None
            continue
        if current is not None:
            kv = re.match(r'^\s*(trusted_hash|enabled)\s*=\s*(.+?)\s*$', line)
            if kv:
                current[kv.group(1)] = kv.group(2)
    return entries


def codex_checks(kit):
    path, lines = codex_toml_lines(kit)
    warnings = []
    table = ""
    for n, line in enumerate(lines, 1):
        if INLINE_HOOKS.match(line):
            raise Refusal("%s has inline hook groups (line %d: %s); Codex would warn at "
                          "every start that it loads hooks from both files. Move them to "
                          "hooks.json, or skip Codex" % (path, n, line.strip()))
        h = re.match(r"^\s*\[([^\]]+)\]\s*$", line)
        if h:
            table = h.group(1).strip()
            continue
        if table == "features" and re.match(r"^\s*(hooks|codex_hooks)\s*=\s*false\b", line):
            warnings.append("%s turns hooks off ([features] %s); Codex will skip the probe"
                            % (path, line.strip()))
    req = "/etc/codex/requirements.toml"
    try:
        with open(req, encoding="utf-8", errors="replace") as f:
            if re.search(r"(?m)^\s*allow_managed_hooks_only\s*=\s*true\b", f.read()):
                warnings.append("%s sets allow_managed_hooks_only = true; Codex runs no user "
                                "hooks, the probe's included" % req)
    except OSError:
        pass
    return warnings


def claude_warnings(kit, doc):
    w = []
    if doc.get("disableAllHooks") is True:
        w.append("disableAllHooks is true in your settings; Claude Code runs no hooks")
    managed = "/Library/Application Support/ClaudeCode/managed-settings.json"
    try:
        with open(managed, encoding="utf-8", errors="replace") as f:
            if "allowManagedHooksOnly" in f.read():
                w.append("%s sets allowManagedHooksOnly; user hooks may not run" % managed)
    except OSError:
        pass
    if os.environ.get("CLAUDE_CONFIG_DIR"):
        w.append("CLAUDE_CONFIG_DIR is set here, so the kit used %s; a Claude Code started "
                 "without it reads ~/.claude instead" % kit.claude_dir())
    # K1: the Claude Code extension may get its own CLAUDE_CONFIG_DIR from
    # the editor's claudeCode.environmentVariables; the panel then reads
    # another folder, and 10.2's panel steps would log nothing.
    mine = os.path.realpath(kit.claude_dir())
    for label, _path, _names, cfg, _note in editor_claude_envs(kit):
        if not isinstance(cfg, str) or not cfg.strip():
            continue
        folder = cfg.strip()
        for var in ("${env:HOME}", "${HOME}", "$HOME"):
            if folder.startswith(var):
                folder = kit.home + folder[len(var):]
        folder = os.path.expanduser(folder)
        if os.path.realpath(folder) != mine:
            w.append("%s's Claude Code extension uses CLAUDE_CONFIG_DIR=%s "
                     "(claudeCode.environmentVariables), so its panel reads that folder, not "
                     "%s; run CLAUDE_CONFIG_DIR=%s probe.sh install claude too"
                     % (label, cfg, kit.claude_dir(), shell_path(folder, kit.home)))
    return w


def gemini_warnings(kit):
    w = []
    for path in (os.path.join(kit.gemini_home(), "settings.json"),
                 "/Library/Application Support/GeminiCli/settings.json",
                 "/Library/Application Support/GeminiCli/system-defaults.json"):
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        for key, note in (("allowedExtensions", "security.allowedExtensions is set; the "
                           "probe's folder must match it, or Gemini skips the extension"),
                          ("hooksConfig", "hooksConfig is set; check that it does not "
                           "turn hooks off"),
                          ("enableHooks", "tools.enableHooks is set; check that it is not "
                           "false")):
            if key in text:
                w.append("%s: %s" % (path, note))
    return w


# ---------------------------------------------------------- install, restore

def install_file_agent(kit, agent, extra):
    path = kit.agent_file(agent)
    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        raise NotFound("%s was not found (no %s); start it once first, or skip it"
                       % (AGENT_NAMES[agent], folder))
    specs = specs_for(agent, extra)
    snap = Snapshot(path)
    snap.check_writable()
    doc = parse_json(snap)
    warnings = []
    if agent == "cursor":
        check_cursor(doc, path)
    else:
        check_nested(doc, path, agent == "codex")
    if agent == "codex":
        warnings += codex_checks(kit)
    if agent == "claude":
        warnings += claude_warnings(kit, doc)
    kit.ensure_probe()
    new, notes = plan_install(kit, doc, agent, specs)
    manifest = kit.load_manifest(agent)
    kit.say("%s: %s%s" % (AGENT_NAMES[agent], path,
                          (" (a symlink to %s)" % snap.target) if snap.is_link else ""))
    probe_paths = {"probe_main": kit.main, "probe_space": kit.space}
    if snap.exists and new == doc:
        kit.say("  The probe's %d handlers are already in place; nothing changed." % len(specs))
        if manifest is None:
            manifest = {"agent": agent, "file": path, "target": snap.target,
                        "existed_before": True, "backups": [],
                        "installed_at": now_text(), "extra": extra,
                        "note": "no backup: the handlers were already there"}
            manifest.update(probe_paths)
            kit.save_manifest(agent, manifest)
    else:
        new_bytes = dumps(new)
        backup = kit.backup(agent, snap) if snap.exists else None
        safe_write(snap, new_bytes)
        if manifest is None:
            # added_version: Cursor's file had no "version", and install
            # added "version": 1, which restore then takes out again.
            manifest = {"agent": agent, "file": path, "target": snap.target,
                        "existed_before": snap.exists, "backups": [],
                        "installed_at": now_text(), "extra": extra,
                        "added_version": agent == "cursor" and "version" not in doc}
        if backup:
            manifest["backups"].append(backup)
        manifest["extra"] = extra
        manifest.update(probe_paths)
        kit.save_manifest(agent, manifest)
        if backup:
            kit.say("  Backed up to %s" % backup)
        else:
            kit.say("  The file did not exist; the kit created it (restore deletes it again).")
        added = [n[6:] for n in notes if n.startswith("added ")]
        others = [n for n in notes if not n.startswith("added ")]
        kit.say("  Added %d of the probe's %d handlers (K.3%s)%s." % (
            len(added), len(specs), ", plus subagentStop for 10.2 (t)" if extra else "",
            ("; " + "; ".join(others)) if others else ""))
        kit.say("  The file was rewritten with 2-space indentation; restore puts the "
                "original bytes back when nothing else changed.")
    foreign = foreign_dirs(kit, new, flat=agent == "cursor")
    if foreign:
        warnings.append("the file also holds " + foreign_note(kit, foreign, agent))
    write_installed(kit, agent)
    for w in warnings:
        kit.say("  Warning: " + w)
    if agent == "codex":
        kit.say("  Next (10.4): first run codex exec once before trusting (expect no probe "
                "lines). Then start codex in a terminal, choose Trust all and continue, and "
                "confirm (or run /hooks). Until then Codex skips the probe's hooks, also in "
                "codex exec. The kit never writes Codex's trust.")
    elif agent == "claude":
        kit.say("  Claude Code applies hook edits to running sessions; /hooks (terminal) or "
                "the Hooks dialog (Cursor panel) lists them. Folders not yet trusted run no "
                "hooks in the terminal.")
    elif agent == "cursor":
        kit.say("  Cursor reloads hooks.json when it changes.")
    return True


def restore_file_agent(kit, agent):
    manifest = kit.load_manifest(agent)
    path = (manifest or {}).get("file") or kit.agent_file(agent)
    kit.say("%s: %s" % (AGENT_NAMES[agent], path))
    if agent == "claude":
        stop_block_window(kit, False)
    snap = Snapshot(path)
    if not snap.exists:
        if manifest and manifest.get("existed_before") and manifest.get("backups"):
            kit.say("  The file is gone. Its backup from before the install is %s; copy it "
                    "back by hand if you want it." % manifest["backups"][0])
        else:
            kit.say("  Nothing to restore: the file does not exist.")
        kit.archive_manifest(agent)
        return True
    snap.check_writable()
    try:
        doc = parse_json(snap)
    except Refusal as exc:
        hint = ""
        if manifest and manifest.get("backups"):
            hint = " Its backup from before the install is %s." % manifest["backups"][0]
        raise Refusal(str(exc) + hint)
    flat = agent == "cursor"
    codex = agent == "codex"
    if flat:
        check_cursor(doc, path, require_version=False)
    else:
        check_nested(doc, path, False)
    foreign = foreign_dirs(kit, doc, flat=flat)
    removed, minimal, keep_hooks = strip_variants(kit, doc, agent)
    if removed == 0:
        if foreign:
            # The manifest stays: these are another folder's handlers.
            raise Unfinished("none of this folder's probe handlers are in the file, but it holds " +
                             foreign_note(kit, foreign, agent))
        kit.say("  No probe handlers in the file; nothing changed.")
        kit.archive_manifest(agent)
        return True
    existed = manifest.get("existed_before", True) if manifest else True
    backups = (manifest or {}).get("backups") or []
    if manifest and not existed and minimal in ({}, {"version": 1}):
        safe_write(snap, None)
        kit.say("  Removed the probe's %d handlers; the file was the kit's own, so it was "
                "deleted, as before the install." % removed)
    elif existed and backups:
        first = backups[0]
        try:
            with open(first, "rb") as f:
                original_bytes = f.read()
            original = parse_json(_BytesSnap(first, original_bytes))
        except (OSError, Refusal):
            original_bytes, original = None, None
        if original is not None and same_as_backup(manifest, original, minimal, keep_hooks,
                                                   codex, flat):
            safe_write(snap, original_bytes)
            kit.say("  Removed the probe's %d handlers; the file now equals its backup "
                    "from before the install, byte for byte (%s)." % (removed, first))
        else:
            safe_write(snap, dumps(minimal))
            kit.say("  Removed the probe's %d handlers. The file had other changes since the "
                    "install (by you or the agent); they were kept. The backup from before "
                    "the install is %s." % (removed, first))
    elif manifest and not existed:
        safe_write(snap, dumps(minimal))
        kit.say("  Removed the probe's %d handlers. The kit had created this file, and it now "
                "holds other settings too (written by you or the agent since); they were kept."
                % removed)
    else:
        safe_write(snap, dumps(minimal))
        kit.say("  Removed the probe's %d handlers (the kit has no record of this file from "
                "before the install, so there was nothing to compare with)." % removed)
    leftover = []
    if os.path.exists(path):
        after = parse_json(Snapshot(path))
        leftover = count_kit(kit, after, agent, flat=flat)
        if agent == "claude":
            leftover += stop_block_entries(kit, after)
    if leftover:
        raise Refusal("%d probe handlers are still in %s" % (len(leftover), path))
    if foreign:
        # This folder's handlers are out; the manifest stays until the
        # other folder's are too.
        raise Unfinished("this folder's probe handlers were removed, but the file still holds " +
                         foreign_note(kit, foreign, agent))
    kit.archive_manifest(agent)
    if agent == "codex":
        kit.say("  Codex's trust entries for the probe stay in config.toml (the kit never "
                "edits it). They are harmless; collect.sh lists them, and you can delete "
                'those [hooks.state."…hooks.json:…"] tables by hand.')
    return True


def same_as_backup(manifest, original, minimal, keep_hooks, codex, flat):
    """True when the file without the probe's handlers says what the backup
    said: equal, or equal but for "version": 1 that install added to a
    Cursor file, or for empty containers (an empty event list or group that
    the user had, or one the removal left)."""
    cands = [minimal, keep_hooks]
    added_version = (manifest or {}).get("added_version", flat and "version" not in original)
    if flat and added_version:
        cands += [{k: v for k, v in c.items() if k != "version"}
                  for c in cands if c.get("version") == 1]
    if original in cands:
        return True
    pruned = prune_empty(original, codex=codex, flat=flat)
    return any(prune_empty(c, codex=codex, flat=flat) == pruned for c in cands)


class _BytesSnap:
    def __init__(self, path, data):
        self.path = path
        self.data = data

    @property
    def exists(self):
        return True


# ------------------------------------------------------------------- Gemini

def find_gemini():
    override = os.environ.get("AWAKE_PREFLIGHT_GEMINI")
    if override is not None:
        return override or None
    found = shutil.which("gemini")
    if found:
        return found
    for cand in ("/opt/homebrew/bin/gemini", "/usr/local/bin/gemini"):
        if os.access(cand, os.X_OK):
            return cand
    return None


def run_gemini(kit, gemini, args):
    try:
        res = subprocess.run([gemini] + args, stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             timeout=60, check=False)
    except subprocess.TimeoutExpired:
        return 124, "gemini %s did not finish in 60 s" % " ".join(args)
    except OSError as exc:
        return 127, "cannot run %s: %s" % (gemini, exc.strerror)
    return res.returncode, res.stdout.decode("utf-8", "replace")


def gemini_link_dir(kit):
    return os.path.join(kit.gemini_home(), "extensions", GEMINI_EXT_NAME)


def gemini_record_source(link_dir):
    try:
        with open(os.path.join(link_dir, ".gemini-extension-install.json"), encoding="utf-8") as f:
            data = json.load(f)
        return data.get("source") if isinstance(data, dict) else None
    except (OSError, ValueError):
        return None


def gemini_ext_files(kit):
    manifest = {"name": GEMINI_EXT_NAME, "version": "1.0.0",
                "description": "Awake preflight probe (docs/plans/agent-keep-awake.md, 10.5): "
                               "logs when Gemini CLI's hooks fire, without prompt text. "
                               "Remove with tools/ai-preflight/probe.sh restore gemini."}
    hooks = {}
    for spec in GEMINI_SPECS:
        hooks.setdefault(spec.event, []).append(
            {"matcher": spec.matcher, "hooks": [kit.handler("gemini", spec)]})
    return {"gemini-extension.json": dumps(manifest),
            os.path.join("hooks", "hooks.json"): dumps({"hooks": hooks})}


def other_gemini_ext_named(kit, name):
    """Another extension folder under ~/.gemini/extensions that declares name."""
    ext_root = os.path.join(kit.gemini_home(), "extensions")
    try:
        entries = sorted(os.listdir(ext_root))
    except OSError:
        return None
    for entry in entries:
        d = os.path.join(ext_root, entry)
        if not os.path.isdir(d) or entry == name:
            continue
        for cand in (d, gemini_record_source(d)):
            if not cand:
                continue
            try:
                with open(os.path.join(cand, "gemini-extension.json"), encoding="utf-8") as f:
                    if json.load(f).get("name") == name:
                        return d
            except (OSError, ValueError, AttributeError):
                continue
    return None


def write_gemini_ext(kit):
    if "$" in kit.main or "`" in kit.main:
        raise Refusal("the probe's path has a $ or `, which Gemini CLI would substitute (K2)")
    kit.ensure_probe()
    for rel, data in gemini_ext_files(kit).items():
        path = os.path.join(kit.gemini_ext, rel)
        os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=".tmp.", dir=os.path.dirname(path))
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)


def install_gemini(kit):
    home = kit.gemini_home()
    gemini = find_gemini()
    if not gemini:
        raise NotFound("Gemini CLI was not found (no gemini on the PATH, in /opt/homebrew/bin "
                       "or /usr/local/bin); skip 10.5")
    if not os.path.isdir(home):
        raise NotFound("Gemini CLI has no %s yet; start gemini once first" % home)
    other = other_gemini_ext_named(kit, GEMINI_EXT_NAME)
    if other:
        raise Refusal("another extension folder, %s, already declares the name %s; Gemini "
                      "would not start with two" % (other, GEMINI_EXT_NAME))
    link_dir = gemini_link_dir(kit)
    kit.say("Gemini CLI: extension %s in %s, linked as %s" % (
        GEMINI_EXT_NAME, kit.gemini_ext, link_dir))
    write_gemini_ext(kit)
    for w in gemini_warnings(kit):
        kit.say("  Warning: " + w)
    if os.path.lexists(link_dir):
        if os.path.realpath(gemini_record_source(link_dir) or "") == os.path.realpath(kit.gemini_ext):
            kit.say("  Already linked (%s); the extension's files were refreshed." % link_dir)
            if kit.load_manifest("gemini") is None:
                kit.save_manifest("gemini", {"agent": "gemini", "linked_by": "unknown",
                                             "link_dir": link_dir, "ext_dir": kit.gemini_ext,
                                             "installed_at": now_text()})
            write_installed(kit, "gemini")
            return True
        raise Refusal("%s already exists and is not the probe's link; remove it with gemini "
                      "extensions uninstall %s first" % (link_dir, GEMINI_EXT_NAME))
    code, out = run_gemini(kit, gemini, ["extensions", "link", kit.gemini_ext, "--consent"])
    if code != 0 or gemini_record_source(link_dir) is None:
        kit.say("  gemini extensions link said:")
        for line in out.strip().splitlines()[-15:]:
            kit.say("    " + line)
        raise Refusal("gemini extensions link failed (exit %d); nothing is linked" % code)
    manifest = kit.load_manifest("gemini") or {}
    manifest.update({"agent": "gemini", "linked_by": "gemini", "link_dir": link_dir,
                     "ext_dir": kit.gemini_ext, "installed_at": now_text()})
    kit.save_manifest("gemini", manifest)
    write_installed(kit, "gemini")
    kit.say("  Linked with gemini extensions link --consent (your install command is the "
            "consent Gemini otherwise asks for). Running Gemini sessions pick it up after a "
            "restart; gemini extensions list should show %s." % GEMINI_EXT_NAME)
    return True


def gemini_record(kit):
    """10.5: the same extension through a hand-written link record (K14)."""
    gemini = find_gemini()
    link_dir = gemini_link_dir(kit)
    kit.say("Gemini CLI: a hand-written link record in %s" % link_dir)
    if not os.path.isdir(kit.gemini_home()):
        raise NotFound("Gemini CLI has no %s yet; start gemini once first" % kit.gemini_home())
    write_gemini_ext(kit)
    if os.path.lexists(link_dir):
        if gemini_record_source(link_dir) is None or os.path.realpath(
                gemini_record_source(link_dir)) != os.path.realpath(kit.gemini_ext):
            raise Refusal("%s exists and is not the probe's link" % link_dir)
        if not gemini:
            raise Refusal("the probe is linked, and gemini is not found to uninstall it first")
        code, out = run_gemini(kit, gemini, ["extensions", "uninstall", GEMINI_EXT_NAME])
        kit.say("  gemini extensions uninstall %s: exit %d" % (GEMINI_EXT_NAME, code))
        if os.path.lexists(link_dir):
            raise Refusal("%s is still there after the uninstall" % link_dir)
    os.makedirs(link_dir, mode=0o755)
    record = json.dumps({"source": kit.gemini_ext, "type": "link"}, indent=2)
    with open(os.path.join(link_dir, ".gemini-extension-install.json"), "w") as f:
        f.write(record)
    manifest = kit.load_manifest("gemini") or {}
    manifest.update({"agent": "gemini", "linked_by": "record", "link_dir": link_dir,
                     "ext_dir": kit.gemini_ext, "installed_at": now_text()})
    kit.save_manifest("gemini", manifest)
    write_installed(kit, "gemini")
    kit.say('  Wrote {"source": "%s", "type": "link"}. Start gemini: does it load the probe '
            "without gemini extensions link?" % kit.gemini_ext)
    return True


def restore_gemini(kit):
    manifest = kit.load_manifest("gemini") or {}
    link_dir = manifest.get("link_dir") or gemini_link_dir(kit)
    ext_dir = kit.gemini_ext
    kit.say("Gemini CLI: %s and %s" % (link_dir, ext_dir))
    problems = []
    if manifest.get("allowlist_added"):
        try:
            gemini_allowlist(kit, "off")
        except Refusal as exc:
            problems.append(str(exc))
    if not os.path.lexists(link_dir) and not os.path.exists(ext_dir) and not problems:
        kit.say("  Not installed; nothing to restore.")
        kit.archive_manifest("gemini")
        return True
    if os.path.lexists(link_dir):
        source = gemini_record_source(link_dir)
        if source is None or os.path.realpath(source) != os.path.realpath(ext_dir):
            problems.append("%s is not the probe's link; left alone" % link_dir)
        else:
            gemini = find_gemini()
            if gemini:
                code, _ = run_gemini(kit, gemini, ["extensions", "uninstall", GEMINI_EXT_NAME])
                kit.say("  gemini extensions uninstall %s: exit %d" % (GEMINI_EXT_NAME, code))
            if os.path.lexists(link_dir):
                names = sorted(os.listdir(link_dir))
                if names == [".gemini-extension-install.json"]:
                    os.unlink(os.path.join(link_dir, names[0]))
                    os.rmdir(link_dir)
                    kit.say("  Removed the link record.")
                else:
                    problems.append("%s holds other files (%s); left alone"
                                    % (link_dir, ", ".join(names)))
    else:
        kit.say("  No link folder.")
    if os.path.isdir(ext_dir):
        ours = set(gemini_ext_files(kit))
        found = set()
        for root, _, files in os.walk(ext_dir):
            for name in files:
                found.add(os.path.relpath(os.path.join(root, name), ext_dir))
        extra = sorted(found - ours)
        if extra:
            problems.append("%s holds other files (%s); left alone" % (ext_dir, ", ".join(extra)))
        else:
            shutil.rmtree(ext_dir)
            kit.say("  Removed the extension folder.")
    if problems:
        raise Refusal("; ".join(problems))
    kit.archive_manifest("gemini")
    return True


NOMATCH = "^nomatch$"


def gemini_allowlist(kit, mode):
    """10.5's allowlist check: adds or removes
    "security": {"allowedExtensions": ["^nomatch$"]} in ~/.gemini/settings.json."""
    path = os.path.join(kit.gemini_home(), "settings.json")
    if not os.path.isdir(kit.gemini_home()):
        raise NotFound("Gemini CLI has no %s yet" % kit.gemini_home())
    snap = Snapshot(path)
    snap.check_writable()
    try:
        doc = parse_json(snap)
    except Refusal:
        raise Refusal('%s is not plain JSON (comments?), which Gemini CLI allows but the kit '
                      'does not edit. For this step add "security": {"allowedExtensions": '
                      '["%s"]} by hand, start gemini, then remove it again' % (path, NOMATCH))
    manifest = kit.load_manifest("gemini") or {"agent": "gemini"}
    new = copy.deepcopy(doc)
    sec = new.get("security")
    if sec is not None and not isinstance(sec, dict):
        raise Refusal('%s: "security" is not an object' % path)
    if mode == "on":
        if isinstance(sec, dict) and "allowedExtensions" in sec:
            if sec["allowedExtensions"] == [NOMATCH]:
                kit.say("The allowlist test setting is already in %s." % path)
                return True
            raise Refusal("%s already has security.allowedExtensions; the kit leaves your "
                          "allowlist alone. Do this step by hand, or skip it" % path)
        if sec is None:
            new["security"] = {"allowedExtensions": [NOMATCH]}
        else:
            sec["allowedExtensions"] = [NOMATCH]
        backup = kit.backup("gemini", snap) if snap.exists else None
        safe_write(snap, dumps(new))
        manifest.update({"allowlist_added": True, "allowlist_backup": backup,
                         "allowlist_existed_before": snap.exists,
                         "allowlist_security_added": sec is None})
        kit.save_manifest("gemini", manifest)
        kit.say('Added "security": {"allowedExtensions": ["%s"]} to %s%s. Start gemini: it '
                "should start and skip the probe. Then run probe.sh gemini-allowlist off."
                % (NOMATCH, path, (" (backup %s)" % backup) if backup else ""))
        return True
    if not (isinstance(sec, dict) and sec.get("allowedExtensions") == [NOMATCH]):
        kit.say("The allowlist test setting is not in %s; nothing to remove." % path)
        manifest.pop("allowlist_added", None)
        kit.save_manifest("gemini", manifest)
        return True
    del sec["allowedExtensions"]
    if manifest.get("allowlist_security_added") and not sec:
        del new["security"]
    backup = manifest.get("allowlist_backup")
    original = None
    if backup:
        try:
            with open(backup, "rb") as f:
                original = f.read()
        except OSError:
            original = None
    if original is not None and parse_json(_BytesSnap(backup, original)) == new:
        safe_write(snap, original)
    elif not manifest.get("allowlist_existed_before", True) and new == {}:
        safe_write(snap, None)
    else:
        safe_write(snap, dumps(new))
    manifest.pop("allowlist_added", None)
    kit.save_manifest("gemini", manifest)
    kit.say("Removed the allowlist test setting from %s." % path)
    return True


# ------------------------------------------------------------------- status

def codex_trusted(kit, path, entries):
    """How many of the kit's Codex handlers have a trusted_hash in
    config.toml under "<hooks.json path>:<event label>:<group>:<handler>"
    (K13; the path as given, or as resolved)."""
    trust = codex_trust(kit)
    count = 0
    for event, gi, hi, *_ in entries:
        for p in dict.fromkeys((path, os.path.realpath(path))):
            key = "%s:%s:%d:%d" % (p, snake(event), gi, hi)
            if "trusted_hash" in trust.get(key, {}):
                count += 1
                break
    return count


def status_agent(kit, agent, extra_default=False):
    manifest = kit.load_manifest(agent)
    if agent == "gemini":
        link_dir = gemini_link_dir(kit)
        source = gemini_record_source(link_dir) if os.path.isdir(link_dir) else None
        linked = source is not None and os.path.realpath(source) == os.path.realpath(kit.gemini_ext)
        hooks_ok = False
        try:
            with open(kit.agent_file("gemini"), "rb") as f:
                hooks_ok = f.read() == gemini_ext_files(kit)[os.path.join("hooks", "hooks.json")]
        except OSError:
            pass
        if not os.path.exists(kit.gemini_ext) and not os.path.lexists(link_dir):
            kit.say("Gemini CLI: not installed (no %s, no %s)" % (kit.gemini_ext, link_dir))
            return
        kit.say("Gemini CLI: extension folder %s (%s); link %s (%s)%s" % (
            kit.gemini_ext, "6 handlers" if hooks_ok else "missing or changed", link_dir,
            ("linked by %s" % (manifest or {}).get("linked_by", "?")) if linked else "not linked",
            "; allowlist test setting on" if (manifest or {}).get("allowlist_added") else ""))
        return
    path = (manifest or {}).get("file") or kit.agent_file(agent)
    extra = (manifest or {}).get("extra", extra_default)
    specs = specs_for(agent, extra)
    try:
        snap = Snapshot(path)
        doc = parse_json(snap)
    except Refusal as exc:
        kit.say("%s: %s" % (AGENT_NAMES[agent], exc))
        return
    if not snap.exists:
        folder = os.path.dirname(path)
        kit.say("%s: %s (no file%s)" % (AGENT_NAMES[agent], path,
                                         "" if os.path.isdir(folder) else "; agent not found"))
        return
    entries = count_kit(kit, doc, agent, flat=agent == "cursor")
    foreign = foreign_dirs(kit, doc, flat=agent == "cursor")
    labels = [e[5][2] for e in entries]
    missing = [s.label for s in specs if s.label not in labels]
    state = "on" if not missing and len(entries) == len(specs) else (
        "off" if not entries else "partial")
    kit.say("%s: %s: %s (%d of %d probe handlers)%s%s%s" % (
        AGENT_NAMES[agent], path, state, len(entries), len(specs),
        ("; missing " + ", ".join(missing)) if missing and entries else "",
        "; the 10.3 (c) stop-block handler is ON" if agent == "claude"
        and stop_block_entries(kit, doc) else "",
        "; backup %s" % manifest["backups"][0] if manifest and manifest.get("backups") else ""))
    if foreign:
        kit.say("  Also: " + foreign_note(kit, foreign, agent))
    if agent == "codex" and entries:
        trusted = codex_trusted(kit, path, entries)
        kit.say("  Codex trust: %d of %d probe handlers have a trusted_hash in config.toml%s" % (
            trusted, len(entries), "" if trusted == len(entries) else
            " (start codex and trust them; until then they are skipped)"))


# ---------------------------------------------------------------- collector

def extract(kit):
    """The hook sections the kit installed, for collect.sh: only the probe's
    own entries (with their positions), never the user's other hooks."""
    for agent in ("claude", "cursor", "codex"):
        extract_file_agent(kit, agent)
    extract_gemini(kit)


def capture(kit, fn, *args):
    """What fn(kit, *args) says, as text."""
    import io
    old = kit.out
    kit.out = io.StringIO()
    try:
        fn(kit, *args)
        return kit.out.getvalue()
    finally:
        kit.out = old


def write_installed(kit, agent):
    """Keeps the probe's entries for agent as installed in
    state/<agent>-installed.txt, which collect.sh shows, also after a
    restore (10.5 restores Gemini before the final collect)."""
    text = capture(kit, extract_gemini if agent == "gemini" else extract_file_agent,
                   *(() if agent == "gemini" else (agent,)))
    kit.ensure_dirs()
    fd, tmp = tempfile.mkstemp(prefix=".installed.", dir=kit.state)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write("# %s, as installed %s:\n%s" % (AGENT_NAMES[agent], now_text(), text))
    os.replace(tmp, os.path.join(kit.state, "%s-installed.txt" % agent))


def extract_file_agent(kit, agent):
    """The probe's entries in one agent's file, with their positions."""
    manifest = kit.load_manifest(agent)
    path = (manifest or {}).get("file") or kit.agent_file(agent)
    kit.say("== %s: %s" % (AGENT_NAMES[agent], path))
    try:
        snap = Snapshot(path)
        doc = parse_json(snap)
    except Refusal as exc:
        kit.say("  " + str(exc))
        return
    if not snap.exists:
        kit.say("  (no file)")
        return
    if snap.is_link:
        kit.say("  a symlink to %s" % snap.target)
    kit.say("  mode %o" % snap.mode)
    entries = count_kit(kit, doc, agent, flat=agent == "cursor")
    hooks = doc.get("hooks") if isinstance(doc.get("hooks"), dict) else {}
    for event, gi, hi, matcher, h, k in entries:
        size = len(hooks.get(event, []))
        where = ("entry %d of %d" % (gi, size)) if hi is None else (
            "group %d of %d, handler %d" % (gi, size, hi))
        props = {key: value for key, value in h.items() if key != "command"}
        kit.say("  %s [%s]%s: %s %s copy=%s %s" % (
            event, where, (" matcher=%s" % json.dumps(matcher)) if matcher is not None else "",
            k[1], k[2], "space" if k[0] == kit.space else "main", json.dumps(props)))
    if not entries:
        kit.say("  (no probe handlers)")
    foreign = foreign_dirs(kit, doc, flat=agent == "cursor")
    if foreign:
        kit.say("  Also: " + foreign_note(kit, foreign, agent))
    if agent == "claude":
        for event, gi, hi in stop_block_entries(kit, doc):
            kit.say("  %s [group %d, handler %d]: the 10.3 (c) stop-block handler, still on"
                    % (event, gi, hi))
    if agent == "codex":
        trust = codex_trust(kit)
        kit.say("  config.toml [hooks.state] tables for this hooks.json (K13):")
        shown = 0
        for p in dict.fromkeys((path, os.path.realpath(path))):
            for key, vals in trust.items():
                if key.startswith(p + ":"):
                    mine = any(key.endswith(":%s:%d:%d" % (snake(e), g, i))
                               for e, g, i, *_ in entries)
                    kit.say('    [hooks.state."%s"] %s%s' % (
                        key, " ".join("%s = %s" % kv for kv in sorted(vals.items())),
                        "  <- the probe's" if mine else ""))
                    shown += 1
        if not shown:
            kit.say("    (none)")
        try:
            for w in codex_checks(kit):
                kit.say("  Warning: " + w)
        except Refusal as exc:
            kit.say("  " + str(exc))


def extract_gemini(kit):
    kit.say("== Gemini CLI")
    status_agent(kit, "gemini")
    for rel in ("gemini-extension.json", os.path.join("hooks", "hooks.json")):
        p = os.path.join(kit.gemini_ext, rel)
        if os.path.exists(p):
            kit.say("  %s:" % p)
            with open(p, encoding="utf-8") as f:
                for line in f.read().splitlines():
                    kit.say("    " + line)
    link_dir = gemini_link_dir(kit)
    rec = os.path.join(link_dir, ".gemini-extension-install.json")
    if os.path.exists(rec):
        with open(rec, encoding="utf-8", errors="replace") as f:
            kit.say("  %s: %s" % (rec, " ".join(f.read().split())))
    for w in gemini_warnings(kit):
        kit.say("  Warning: " + w)


def strip_jsonc(text):
    """Removes // and /* */ comments outside strings, for reading VS Code's
    and Cursor's settings.json (read only)."""
    out = []
    i = 0
    n = len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            out.append(c)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def editor_claude_envs(kit):
    """K1 and 10.2: for Cursor's and VS Code's user settings.json, a tuple
    (label, path, names, CLAUDE_CONFIG_DIR or None, note): the names of the
    Claude Code extension's claudeCode.environmentVariables, and the value
    of CLAUDE_CONFIG_DIR among them. note says why there are none."""
    out = []
    for label, path in (
            ("Cursor", os.path.join(kit.home, "Library", "Application Support", "Cursor",
                                    "User", "settings.json")),
            ("VS Code", os.path.join(kit.home, "Library", "Application Support", "Code",
                                     "User", "settings.json"))):
        if not os.path.exists(path):
            out.append((label, path, [], None, "not found"))
            continue
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError as exc:
            out.append((label, path, [], None, "cannot read: %s" % exc.strerror))
            continue
        try:
            doc = json.loads(strip_jsonc(text))
        except ValueError:
            doc = None
        if not isinstance(doc, dict):
            out.append((label, path, [], None,
                        "exists; not parsed; claudeCode.environmentVariables %s in its text"
                        % ("appears" if "claudeCode.environmentVariables" in text
                           else "does not appear")))
            continue
        env = doc.get("claudeCode.environmentVariables")
        if env is None:
            out.append((label, path, [], None, "no claudeCode.environmentVariables"))
            continue
        names = []
        cfg = None
        if isinstance(env, list):
            for item in env:
                if isinstance(item, dict) and isinstance(item.get("name"), str):
                    names.append(item["name"])
                    if item["name"] == "CLAUDE_CONFIG_DIR":
                        cfg = item.get("value")
        elif isinstance(env, dict):
            names = list(env)
            cfg = env.get("CLAUDE_CONFIG_DIR")
        out.append((label, path, names, cfg if isinstance(cfg, str) else None, ""))
    return out


def editor_settings(kit):
    """Prints editor_claude_envs: only the variables' names, and the value
    of CLAUDE_CONFIG_DIR."""
    for label, path, names, cfg, note in editor_claude_envs(kit):
        if note:
            kit.say("%s user settings: %s (%s)" % (label, path, note))
            continue
        kit.say("%s user settings: %s: claudeCode.environmentVariables names: %s%s" % (
            label, path, ", ".join(n for n in names if re.match(r"^[A-Za-z0-9_]{1,64}$", n))
            or "(none)", ("; CLAUDE_CONFIG_DIR=%s" % cfg) if cfg is not None else ""))


def app_version(app):
    """An app bundle's version from its Info.plist, or why there is none."""
    import plistlib
    plist = os.path.join(app, "Contents", "Info.plist")
    if not os.path.exists(plist):
        return "not found"
    try:
        with open(plist, "rb") as f:
            info = plistlib.load(f)
        return "%s (build %s)" % (info.get("CFBundleShortVersionString", "?"),
                                  info.get("CFBundleVersion", "?"))
    except Exception:
        return "unreadable Info.plist"


def short_run(argv, seconds=15):
    """The first line of a short command's output, or why there is none."""
    try:
        res = subprocess.run(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=seconds)
    except subprocess.TimeoutExpired:
        return "no answer in %d s" % seconds
    except OSError as exc:
        return "cannot run: %s" % exc.strerror
    lines = res.stdout.decode("utf-8", "replace").strip().splitlines()
    return (lines[0] if lines else "(no output)") + (
        "" if res.returncode == 0 else " (exit %d)" % res.returncode)


def editor_versions(kit):
    for label, app in (("Claude (Desktop app, 10.3 (g))", "/Applications/Claude.app"),
                       ("Codex app (10.4)", "/Applications/Codex.app"),
                       ("Zed", "/Applications/Zed.app")):
        kit.say("%s: %s" % (label, app_version(app)))
    for label, app, ext_dir in (
            ("Cursor", "/Applications/Cursor.app", os.path.join(kit.home, ".cursor", "extensions")),
            ("VS Code", "/Applications/Visual Studio Code.app",
             os.path.join(kit.home, ".vscode", "extensions"))):
        kit.say("%s: %s" % (label, app_version(app)))
        try:
            names = sorted(os.listdir(ext_dir))
        except OSError:
            names = []
        for name in names:
            if not (name.startswith("anthropic.claude-code") or name.startswith("openai.chatgpt")
                    or name.startswith("google.geminicodeassist")):
                continue
            pkg = os.path.join(ext_dir, name, "package.json")
            ver = "?"
            try:
                with open(pkg, encoding="utf-8") as f:
                    ver = json.load(f).get("version", "?")
            except (OSError, ValueError):
                pass
            bundled = ""
            if name.startswith("anthropic.claude-code"):
                cand = find_exe_in(os.path.join(ext_dir, name), "claude")
                if cand:
                    bundled = "; bundled CLI at %s (--version: %s)" % (
                        cand, short_run([cand, "--version"]))
                else:
                    bundled = "; no bundled claude executable found"
            kit.say("  extension %s: version %s%s" % (name, ver, bundled))


LOG_START = re.compile(r"^(\d\d:\d\d:\d\d\.\d{3}) (\S+) (\S+) pid=(\d+) START$")
LOG_DETAIL = re.compile(r"^  \[(\d+)\] (.*)$")


def summarize_logs(kit, paths):
    """A count per agent and handler, and the lines that need a look."""
    for path in paths:
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                lines = f.read().splitlines()
        except OSError:
            continue
        starts = {}
        done = set()
        counts = {}
        flags = []
        for line in lines:
            m = LOG_START.match(line)
            if m:
                starts[m.group(4)] = (m.group(2), m.group(3), m.group(1))
                key = "%s %s" % (m.group(2), m.group(3))
                counts[key] = counts.get(key, 0) + 1
                continue
            m = LOG_DETAIL.match(line)
            if not m:
                continue
            pid, text = m.group(1), m.group(2)
            who = starts.get(pid, ("?", "?", "?"))
            if text.startswith("done "):
                done.add(pid)
                if "log=fallback" in text:
                    flags.append("%s %s %s: wrote to the fallback log" % (who[2], who[0], who[1]))
                if "tmpw=fail" in text:
                    flags.append("%s %s %s: could not write to /tmp" % (who[2], who[0], who[1]))
            elif text.startswith("stdin ") and not text.startswith("stdin eof"):
                flags.append("%s %s %s: %s" % (who[2], who[0], who[1], text))
            elif text.startswith("watchdog") or text.startswith("facts"):
                flags.append("%s %s %s: %s" % (who[2], who[0], who[1], text))
        for pid, who in starts.items():
            if pid not in done:
                flags.append("%s %s %s: START without a done line (killed before it finished?)"
                             % (who[2], who[0], who[1]))
        kit.say("-- %s: %d hook runs" % (os.path.basename(path), len(starts)))
        for key in sorted(counts):
            kit.say("   %5d  %s" % (counts[key], key))
        for f in flags[:200]:
            kit.say("   look: " + f)
        if len(flags) > 200:
            kit.say("   look: (+%d more)" % (len(flags) - 200))


PMSET_LINE = re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d [+-]\d{4}) +(\S+)\s+(.*?)\s*$")


def pmset_events(kit, since):
    """Reads pmset -g log on stdin; prints "EPOCH TYPE line" for each Sleep,
    Wake and DarkWake entry at or after the epoch since (10.6 (c), (g))."""
    for line in sys.stdin.read().splitlines():
        m = PMSET_LINE.match(line)
        if not m or m.group(2) not in ("Sleep", "Wake", "DarkWake"):
            continue
        try:
            t = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S %z").timestamp()
        except ValueError:
            continue
        if t >= since:
            sys.stdout.write("%d %s %s\n" % (t, m.group(2), " ".join(line.split())[:240]))


def print_block(kit, agent, extra):
    kit.say("// The probe's handlers for %s (%s), for pasting by hand:" % (
        AGENT_NAMES[agent], kit.agent_file(agent)))
    if agent == "gemini":
        sys.stdout.write(gemini_ext_files(kit)[os.path.join("hooks", "hooks.json")].decode())
        return
    doc, _ = plan_install(kit, {"version": 1} if agent == "cursor" else {}, agent,
                          specs_for(agent, extra))
    sys.stdout.write(dumps(doc).decode())


def codex_touch(kit):
    """10.4: points the probe's Codex Stop handler at the other probe copy,
    so its text, and so Codex's hash, changes (K13)."""
    path = kit.agent_file("codex")
    snap = Snapshot(path)
    snap.check_writable()
    doc = parse_json(snap)
    check_nested(doc, path, True)
    entries = [e for e in count_kit(kit, doc, "codex") if e[0] == "Stop" and e[5][2] == "Stop"]
    if not entries:
        raise Refusal("the probe's Codex Stop handler is not in %s; run probe.sh install "
                      "codex first" % path)
    event, gi, hi, _, h, k = entries[0]
    new_path = kit.space if k[0] == kit.main else kit.main
    new = copy.deepcopy(doc)
    new["hooks"][event][gi]["hooks"][hi]["command"] = kit.command(new_path, "codex", "Stop")
    backup = kit.backup("codex", snap)
    safe_write(snap, dumps(new))
    manifest = kit.load_manifest("codex")
    if manifest is not None:
        manifest.setdefault("backups", []).append(backup)
        kit.save_manifest("codex", manifest)
    kit.say("Codex's Stop handler (group %d) now runs %s (backup %s)." % (gi, new_path, backup))
    kit.say("Start codex: the review screen should come back for this one handler, and Stop "
            "lines should be missing until you trust it again. Run codex-touch again to switch "
            "back (install codex also puts it back).")
    return True


def stop_block_entries(kit, doc):
    """(event, group, handler) of each 10.3 (c) Stop handler in doc."""
    found = []
    hooks = doc.get("hooks")
    if not isinstance(hooks, dict):
        return found
    for event, groups in hooks.items():
        if not isinstance(groups, list):
            continue
        for gi, group in enumerate(groups):
            if not isinstance(group, dict) or not isinstance(group.get("hooks", []), list):
                continue
            for hi, h in enumerate(group.get("hooks", [])):
                if kit.is_stop_block(h):
                    found.append((event, gi, hi))
    return found


def remove_stop_block(kit, doc):
    """Removes only the 10.3 (c) Stop handler from doc (in place), and the
    groups and events that it leaves empty."""
    hooks = doc.get("hooks")
    if not isinstance(hooks, dict):
        return 0
    removed = 0
    for event in list(hooks):
        groups = hooks[event]
        if not isinstance(groups, list):
            continue
        new_groups = []
        for group in groups:
            inner = group.get("hooks") if isinstance(group, dict) else None
            if isinstance(inner, list):
                kept = [h for h in inner if not kit.is_stop_block(h)]
                if len(kept) != len(inner):
                    removed += len(inner) - len(kept)
                    if not kept:
                        continue
                    group["hooks"] = kept
            new_groups.append(group)
        if len(new_groups) != len(groups):
            if new_groups:
                hooks[event] = new_groups
            else:
                del hooks[event]
    return removed


def stop_block_window(kit, on):
    """Starts (on) or ends the 20-minute window in which the 10.3 (c) hook
    acts, and forgets which sessions it already held."""
    import time
    if on:
        kit.ensure_dirs()
    try:
        names = os.listdir(kit.state)
    except OSError:
        names = []
    for name in names:
        if name.startswith("stop-block-done-") or name == "stop-block-on":
            try:
                os.unlink(os.path.join(kit.state, name))
            except OSError:
                pass
    if on:
        fd, tmp = tempfile.mkstemp(prefix=".stop-block-on.", dir=kit.state)
        with os.fdopen(fd, "w") as f:
            f.write("%d\n" % int(time.time()))
        os.replace(tmp, os.path.join(kit.state, "stop-block-on"))


def stop_block(kit, mode):
    """10.3 (c): adds or removes a Claude Code Stop handler that holds the
    Stop for 90 s and then exits 2 (awake-stop-block.sh), as a group of its
    own at the end of Stop. It acts only for Claude Code in Terminal, once
    per session, for 20 minutes after on (see the script). restore claude
    removes it too."""
    path = kit.agent_file("claude")
    manifest = kit.load_manifest("claude")
    if mode == "off":
        stop_block_window(kit, False)
    snap = Snapshot(path)
    if mode == "on" and (manifest is None or not snap.exists):
        raise Refusal("the probe is not installed for Claude Code; run probe.sh install claude "
                      "first, so that the log shows what follows the Stop")
    if not snap.exists:
        kit.say("Nothing to remove: %s does not exist." % path)
        return True
    snap.check_writable()
    doc = parse_json(snap)
    check_nested(doc, path, False)
    present = stop_block_entries(kit, doc)
    new = copy.deepcopy(doc)
    if mode == "on":
        if present:
            stop_block_window(kit, True)
            kit.say("The 10.3 (c) Stop handler is already in %s; its 20-minute window starts "
                    "again, and every session can be held once more." % path)
            return True
        if "$" in kit.stop_block or "`" in kit.stop_block:
            raise Refusal("the preflight folder's path has a $ or `")
        text = kit.probe_text(STOP_BLOCK_NAME).encode("utf-8")
        fd, tmp = tempfile.mkstemp(prefix="." + STOP_BLOCK_NAME + ".", dir=kit.dir)
        with os.fdopen(fd, "wb") as f:
            f.write(text)
        os.chmod(tmp, 0o755)
        os.replace(tmp, kit.stop_block)
        new.setdefault("hooks", {}).setdefault("Stop", []).append(
            {"hooks": [kit.stop_block_handler()]})
    else:
        if not present:
            kit.say("The 10.3 (c) Stop handler is not in %s; nothing changed." % path)
            return True
        remove_stop_block(kit, new)
    new_bytes = dumps(new)
    backup = kit.backup("claude", snap)
    safe_write(snap, new_bytes)
    if mode == "on":
        stop_block_window(kit, True)
    if manifest is not None:
        manifest.setdefault("backups", []).append(backup)
        manifest["stop_block"] = mode == "on"
        kit.save_manifest("claude", manifest)
    if mode == "on":
        kit.say("Added the 10.3 (c) Stop handler to %s (backup %s). For the next 20 minutes, the "
                "first Stop of each Claude Code session in Terminal is held 90 s, then Claude goes "
                "on with the turn once. Cursor's agent, the Claude Code panel and claude in "
                "Cursor's terminal are let through (the run log says why for each Stop). Keep "
                "Cursor's chats and the panel idle meanwhile, and turn it off right after the "
                "test with probe.sh stop-block off." % (path, backup))
    else:
        kit.say("Removed the 10.3 (c) Stop handler from %s (backup %s)." % (path, backup))
    return True


# ------------------------------------------- 10.2's extra measurements

def log_append(kit, lines):
    """Appends lines to the current run log (and prints them)."""
    kit.ensure_probe()
    path = os.path.join(kit.logs, "current.log")
    with open(path, "a", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")
    for line in lines:
        kit.say(line)


def find_bundled_claude(kit):
    """The Claude Code extension's bundled claude in Cursor: the newest
    executable file named claude in an anthropic.claude-code-* folder, at
    most four folders down (where exactly it sits is not documented)."""
    root = os.path.join(kit.home, ".cursor", "extensions")
    try:
        names = sorted(n for n in os.listdir(root) if n.startswith("anthropic.claude-code"))
    except OSError:
        names = []
    cands = []
    for n in names:
        c = find_exe_in(os.path.join(root, n), "claude")
        if c:
            cands.append((os.stat(c).st_mtime, c))
    return max(cands)[1] if cands else None


def find_exe_in(base, name, max_depth=4):
    """An executable file called name under base, at most max_depth folders
    down, outside node_modules; None when there is none."""
    for folder, dirs, files in os.walk(base):
        depth = folder[len(base):].count(os.sep)
        dirs[:] = sorted(d for d in dirs if d != "node_modules") if depth < max_depth else []
        if name in files:
            c = os.path.join(folder, name)
            if os.path.isfile(c) and os.access(c, os.X_OK):
                return c
    return None


def terminal_claude(kit):
    """The claude a Terminal runs: on the PATH, else the native install's
    ~/.local/bin/claude, else the old local install's ~/.claude/local/claude
    (which zsh may know only as an alias, so command -v prints the alias)."""
    found = shutil.which("claude")
    if found:
        return found
    for cand in (os.path.join(kit.home, ".local", "bin", "claude"),
                 os.path.join(kit.home, ".claude", "local", "claude")):
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def given_claude(kit, claude):
    """A claude path given by hand (~ allowed), the word terminal for the
    one a Terminal runs, or none for the panel's bundled one."""
    if claude == "terminal":
        return terminal_claude(kit)
    if claude:
        return os.path.expanduser(claude)
    return find_bundled_claude(kit)


def facts_run(kit, args, env=None, stdin=None):
    facts = os.path.join(kit.dir, FACTS_NAME)
    try:
        res = subprocess.run([kit.python, "-I", "-S", facts] + args, input=stdin,
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             env=env, timeout=30)
        return res.stdout.decode("utf-8", "replace").strip() or "(no output)"
    except (subprocess.TimeoutExpired, OSError) as exc:
        return "failed: %s" % type(exc).__name__


NO_AGENT_VIEW = ["--settings", '{"disableAgentView": true}']


def last_look_cmd(kit, claude, no_agent_view=False):
    """10.2's last look from the terminal (W21, B-7): claude agents --json
    in this shell's environment, in a minimal one as the watcher has, and
    with CLAUDE_CODE_CHILD_SESSION=1; daemon status before and after; and
    the time of 10 calls. Output without cwd and name. With no_agent_view
    (10.3 (f)), every call also gets --settings '{"disableAgentView": true}'."""
    import time
    claude = given_claude(kit, claude)
    if not claude or not os.access(claude, os.X_OK):
        raise Refusal("no claude binary given or found; pass its path (from gcomm= in the "
                      "log of a panel event), or the word terminal for the claude you run in "
                      "Terminal")
    kit.ensure_probe()

    def daemon_status():
        try:
            res = subprocess.run([claude, "daemon", "status"], stdin=subprocess.DEVNULL,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
            out = res.stdout.decode("utf-8", "replace").strip().splitlines()[:8]
            return "exit %d: %s" % (res.returncode, " | ".join(out) or "(no output)")
        except (subprocess.TimeoutExpired, OSError) as exc:
            return "failed: %s" % type(exc).__name__

    # Global options go before the subcommand: claude --settings ... agents
    # --json.
    extra = NO_AGENT_VIEW if no_agent_view else []
    look = ["--last-look", claude] + extra
    lines = ["##### %s last look (terminal)%s, %s" % (
        time.strftime("%H:%M:%S"), " with disableAgentView" if no_agent_view else "", claude)]
    lines.append("  daemon status before: " + daemon_status())
    lines.append("  agents --json (this shell): " + facts_run(kit, look))
    lines.append("  daemon status after: " + daemon_status())
    minimal = {"HOME": kit.home, "USER": os.environ.get("USER", ""),
               "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"}
    lines.append("  agents --json (env -i HOME USER PATH, as the watcher): "
                 + facts_run(kit, look, env=minimal))
    child = dict(os.environ, CLAUDE_CODE_CHILD_SESSION="1")
    lines.append("  agents --json (CLAUDE_CODE_CHILD_SESSION=1): "
                 + facts_run(kit, look, env=child))
    start = time.monotonic()
    codes = []
    for _ in range(10):
        try:
            codes.append(subprocess.run([claude] + extra + ["agents", "--json"],
                                        stdin=subprocess.DEVNULL,
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                        timeout=15).returncode)
        except (subprocess.TimeoutExpired, OSError):
            codes.append("timeout")
    total = (time.monotonic() - start) * 1000.0
    lines.append("  10 calls: %d ms in all, %d ms each; exits %s" % (
        round(total), round(total / 10), ",".join(str(c) for c in codes)))
    log_append(kit, lines)


def last_look_hook(kit, mode, claude):
    flag = os.path.join(kit.dir, "last-look-hook")
    if mode == "off":
        if os.path.exists(flag):
            os.unlink(flag)
        kit.say("The in-hook last look is off.")
        return
    claude = given_claude(kit, claude)
    if not claude or not os.access(claude, os.X_OK):
        raise Refusal("no claude binary given or found; pass its path (from gcomm= in the "
                      "log), or the word terminal")
    kit.ensure_probe()
    with open(flag, "w") as f:
        f.write(claude + "\n")
    kit.say("On: each Claude Code Stop now also runs %s agents --json in the background, "
            "with the hook's environment, and logs the result. Run one turn, then turn it off "
            "with probe.sh last-look-hook off." % claude)


IDLE_RE = re.compile(r'"HIDIdleTime"\s*=\s*(\d+)')


def read_idle():
    try:
        res = subprocess.run(["/usr/sbin/ioreg", "-c", "IOHIDSystem"], stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=10)
    except (subprocess.TimeoutExpired, OSError):
        return None
    m = IDLE_RE.search(res.stdout.decode("utf-8", "replace"))
    return int(m.group(1)) / 1e9 if m else None


def idle_watch(kit, seconds, every):
    """B-18 and W26: HIDIdleTime into the run log every few seconds."""
    import time
    end = time.monotonic() + seconds
    log_append(kit, ["##### %s idle watch for %d s, every %d s" % (
        time.strftime("%H:%M:%S"), seconds, every)])
    while True:
        idle = read_idle()
        log_append(kit, ["##### %s idle=%s" % (
            time.strftime("%H:%M:%S"), "NA" if idle is None else "%.3fs" % idle)])
        if time.monotonic() + every > end:
            break
        time.sleep(every)


ASSERT_KEEP = re.compile(r"caffeinate|claude|cursor|code helper|electron|node|codex|gemini|awake",
                         re.IGNORECASE)


def assertions(kit, label):
    """10.2: what the agents hold themselves (pmset -g assertions), only the
    summary and the lines of agent, editor and Awake processes."""
    import time
    try:
        res = subprocess.run(["pmset", "-g", "assertions"], stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
        text = res.stdout.decode("utf-8", "replace")
    except (subprocess.TimeoutExpired, OSError) as exc:
        text = "pmset failed: %s" % type(exc).__name__
    lines = ["##### %s pmset -g assertions%s" % (time.strftime("%H:%M:%S"),
                                                 (" (" + label + ")") if label else "")]
    section = ""
    for line in text.splitlines():
        if not line.startswith(" "):
            section = line.strip()
            continue
        stripped = line.strip()
        if section.startswith("Assertion status system-wide") and re.match(
                r"^(PreventUserIdleSystemSleep|PreventSystemSleep|PreventUserIdleDisplaySleep|"
                r"UserIsActive)\s+\d", stripped):
            lines.append("  " + " ".join(stripped.split()))
        else:
            # "pid 4242(caffeinate): [0x0001] 00:01:00 PreventUserIdleSystemSleep named: ..."
            # keeps the process, the age and the type; never the name, which
            # an app may fill with a window or page title.
            m = re.match(r"^pid (\d+)\((.*?)\):\s*\[[^\]]*\]\s*(\S+)\s+(\S+)", stripped)
            if m and ASSERT_KEEP.search(m.group(2)):
                lines.append("  pid %s(%s) %s %s" % m.groups())
    log_append(kit, lines)


# --------------------------------------------------------------------- main

def expand_agents(names):
    out = []
    for n in names:
        if n == "all":
            out.extend(AGENTS)
        elif n in AGENTS:
            out.append(n)
        else:
            raise Refusal("unknown agent %r; use claude, cursor, codex, gemini or all" % n)
    return list(dict.fromkeys(out))


def main(argv):
    p = argparse.ArgumentParser(prog="kit.py")
    p.add_argument("--dir", required=True)
    p.add_argument("--kit-src", required=True)
    p.add_argument("--python", default="/usr/bin/python3")
    sub = p.add_subparsers(dest="cmd")
    for name in ("install", "restore", "status", "print"):
        s = sub.add_parser(name)
        s.add_argument("agents", nargs="*")
        s.add_argument("--extra", action="store_true")
    sub.add_parser("ensure-probe")
    s = sub.add_parser("new-run")
    s.add_argument("name", nargs="?", default="")
    sub.add_parser("codex-touch")
    s = sub.add_parser("stop-block")
    s.add_argument("mode", choices=("on", "off"))
    sub.add_parser("gemini-record")
    s = sub.add_parser("gemini-allowlist")
    s.add_argument("mode", choices=("on", "off"))
    sub.add_parser("extract")
    sub.add_parser("editor-info")
    s = sub.add_parser("summarize-logs")
    s.add_argument("paths", nargs="*")
    s = sub.add_parser("pmset-events")
    s.add_argument("since", type=int)
    s = sub.add_parser("last-look")
    s.add_argument("claude", nargs="?")
    s.add_argument("--no-agent-view", action="store_true")
    s = sub.add_parser("last-look-hook")
    s.add_argument("mode", choices=("on", "off"))
    s.add_argument("claude", nargs="?")
    s = sub.add_parser("idle-watch")
    s.add_argument("seconds", nargs="?", type=int, default=300)
    s.add_argument("every", nargs="?", type=int, default=10)
    s = sub.add_parser("assertions")
    s.add_argument("label", nargs="*")
    args = p.parse_args(argv)
    kit = Kit(args)
    failed = False
    try:
        if args.cmd in ("install", "restore", "status", "print"):
            agents = expand_agents(args.agents or (["all"] if args.cmd in ("status",) else []))
            if not agents:
                raise Refusal("name an agent: claude, cursor, codex, gemini or all")
            for agent in agents:
                try:
                    if args.cmd == "install":
                        if agent == "gemini":
                            install_gemini(kit)
                        else:
                            install_file_agent(kit, agent, args.extra and agent == "cursor")
                    elif args.cmd == "restore":
                        if agent == "gemini":
                            restore_gemini(kit)
                        else:
                            restore_file_agent(kit, agent)
                    elif args.cmd == "status":
                        status_agent(kit, agent)
                    else:
                        print_block(kit, agent, args.extra)
                except NotFound as exc:
                    kit.say("%s: skipped: %s." % (AGENT_NAMES[agent], exc))
                    if len(agents) == 1 or "all" not in (args.agents or []):
                        failed = True
                except Unfinished as exc:
                    kit.say("  NOT FINISHED: %s." % exc)
                    failed = True
                except Refusal as exc:
                    kit.say("%s: REFUSED: %s." % (AGENT_NAMES[agent], exc))
                    failed = True
            if args.cmd == "status":
                cur = os.path.join(kit.logs, "current.log")
                if os.path.lexists(cur):
                    kit.say("Current run log: %s -> %s" % (cur, os.readlink(cur)))
                else:
                    kit.say("No run log yet (install starts one).")
        elif args.cmd == "ensure-probe":
            kit.ensure_probe()
        elif args.cmd == "new-run":
            kit.ensure_probe()
            kit.say("New run log: %s" % kit.new_run(args.name))
        elif args.cmd == "codex-touch":
            codex_touch(kit)
        elif args.cmd == "stop-block":
            stop_block(kit, args.mode)
        elif args.cmd == "gemini-record":
            gemini_record(kit)
        elif args.cmd == "gemini-allowlist":
            gemini_allowlist(kit, args.mode)
        elif args.cmd == "extract":
            extract(kit)
        elif args.cmd == "editor-info":
            editor_versions(kit)
            editor_settings(kit)
        elif args.cmd == "summarize-logs":
            summarize_logs(kit, args.paths)
        elif args.cmd == "pmset-events":
            pmset_events(kit, args.since)
        elif args.cmd == "last-look":
            last_look_cmd(kit, args.claude, args.no_agent_view)
        elif args.cmd == "last-look-hook":
            last_look_hook(kit, args.mode, args.claude)
        elif args.cmd == "idle-watch":
            idle_watch(kit, max(1, args.seconds), max(1, args.every))
        elif args.cmd == "assertions":
            assertions(kit, " ".join(args.label))
        else:
            p.print_help()
            return 2
    except Refusal as exc:
        kit.say("REFUSED: %s." % exc)
        return 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
