"""Check that every pending_choice kind the GML compares against is actually created.

`pending_choice.kind` values are bare strings shared by the rules, input,
network, AI, and draw modules. A typo in a comparison or `case` label fails
silently at runtime, so this lint cross-references them statically.

    python tools/lint_pending_choices.py

It also checks that every created kind is handled by the shared click handler
`execute_choice_click` (used by both local and network input), unless the kind
is resolved only through action buttons and listed in ACTION_ONLY_KINDS.

Exits nonzero when a compared kind is never created, when a created kind has
no click handler and is not action-only, or when ACTION_ONLY_KINDS is stale.
Assignments that restore a saved choice from a variable are reported as notes.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"

CLICK_HANDLER = re.compile(r"\bexecute_choice_click\s*=\s*function[^{]*\{")

# Choice kinds resolved entirely through action buttons (network_execute_input's
# action switch), so they intentionally have no board-click case.
ACTION_ONLY_KINDS = {
    "adam_breach",
    "back_in_the_day",
    "choose_faction",
    "queen_event",
    "raid_cargo",
    "space_pirate_payment",
}

ASSIGN = re.compile(r"\bpending_choice\s*=\s*(?!=)")
KIND_FIELD = re.compile(r'^\s*kind\s*:\s*"([a-z0-9_]+)"', re.MULTILINE)
KIND_SET = re.compile(r'\bpending_choice\.kind\s*=\s*"([a-z0-9_]+)"')
COMPARE = re.compile(
    r'\b(?:pending_choice|_choice|_pending|_pending_choice)\.kind\s*(?:==|!=)\s*"([a-z0-9_]+)"'
)
SWITCH = re.compile(r"\bswitch\s*\(\s*(?:pending_choice|_choice|_pending|_pending_choice)\.kind\s*\)\s*\{")
CASE = re.compile(r'\bcase\s+"([a-z0-9_]+)"\s*:')


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def balanced_block(text, open_index):
    """Return the text between the brace at open_index and its matching close."""
    depth = 0
    in_string = False
    for i in range(open_index, len(text)):
        ch = text[i]
        if in_string:
            if ch == "\\":
                continue
            if ch == '"':
                in_string = False
        elif ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[open_index + 1:i]
    return text[open_index + 1:]


def top_level_kind(block):
    """Find `kind:` at depth 0 of a struct literal body, ignoring nested structs."""
    depth = 0
    flat = []
    for ch in block:
        if ch in "{[":
            depth += 1
        elif ch in "}]":
            depth -= 1
        elif depth == 0:
            flat.append(ch)
    match = KIND_FIELD.search("".join(flat))
    return match.group(1) if match else None


def line_of(text, index):
    return text.count("\n", 0, index) + 1


def scan():
    created = {}
    used = {}
    unanalyzed = []
    click_handled = None
    for path in sorted(SCRIPTS.glob("*/*.gml")):
        text = strip_comments(path.read_text(encoding="utf-8"))
        rel = path.relative_to(ROOT).as_posix()

        for match in ASSIGN.finditer(text):
            rest = text[match.end():]
            where = f"{rel}:{line_of(text, match.start())}"
            if rest.startswith("undefined"):
                continue
            if rest.startswith("{"):
                kind = top_level_kind(balanced_block(text, match.end()))
                if kind:
                    created.setdefault(kind, where)
                else:
                    unanalyzed.append(where)
            else:
                unanalyzed.append(where)

        for match in KIND_SET.finditer(text):
            created.setdefault(match.group(1), f"{rel}:{line_of(text, match.start())}")

        for match in COMPARE.finditer(text):
            used.setdefault(match.group(1), f"{rel}:{line_of(text, match.start())}")

        for match in SWITCH.finditer(text):
            body = balanced_block(text, match.end() - 1)
            for case in CASE.finditer(body):
                index = match.end() + case.start()
                used.setdefault(case.group(1), f"{rel}:{line_of(text, index)}")
        handler = CLICK_HANDLER.search(text)
        if handler:
            body = balanced_block(text, handler.end() - 1)
            switch = SWITCH.search(body)
            if switch:
                cases = balanced_block(body, switch.end() - 1)
                click_handled = {m.group(1) for m in CASE.finditer(cases)}
    return created, used, unanalyzed, click_handled


def main():
    created, used, unanalyzed, click_handled = scan()
    missing = sorted(set(used) - set(created))
    unused = sorted(set(created) - set(used))
    failed = bool(missing)
    if click_handled is None:
        print("ERROR: could not find the execute_choice_click switch")
        return 1

    print(f"{len(created)} pending_choice kinds created, {len(used)} compared.")
    for kind in missing:
        print(f"ERROR: kind \"{kind}\" compared at {used[kind]} is never created")
    for where in unanalyzed:
        print(f"note: pending_choice assignment at {where} restores a non-literal value")
    for kind in unused:
        print(f"note: kind \"{kind}\" created at {created[kind]} is never compared")
    for kind in sorted(set(created) - click_handled - ACTION_ONLY_KINDS):
        print(f"ERROR: kind \"{kind}\" created at {created[kind]} has no execute_choice_click case")
        failed = True
    for kind in sorted(ACTION_ONLY_KINDS & click_handled):
        print(f"ERROR: kind \"{kind}\" is in ACTION_ONLY_KINDS but has an execute_choice_click case")
        failed = True
    for kind in sorted(ACTION_ONLY_KINDS - set(created)):
        print(f"ERROR: ACTION_ONLY_KINDS lists \"{kind}\", which is never created")
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
