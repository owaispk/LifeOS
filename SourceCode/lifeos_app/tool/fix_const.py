"""Removes `const` where it no longer compiles because Tokens.space* became
getters (PBI-031). Repeats `dart analyze` until no const errors remain.
Usage: python tool/fix_const.py [paths...]
"""
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
DART = r"C:\Users\owais.aized\dev\flutter\bin\dart.bat"
CODES = {
    "CONST_WITH_NON_CONSTANT_ARGUMENT",
    "INVALID_CONSTANT",
    "NON_CONSTANT_LIST_ELEMENT",
    "NON_CONSTANT_MAP_ELEMENT",
    "NON_CONSTANT_MAP_VALUE",
    "NON_CONSTANT_SET_ELEMENT",
    "CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE",
    "CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH",
    "CONST_EVAL_METHOD_INVOCATION",
    "CONST_EVAL_PROPERTY_ACCESS",
    "NON_CONSTANT_DEFAULT_VALUE",
    "NON_CONSTANT_CASE_EXPRESSION",
    "CONST_EVAL_TYPE_NUM",
    "CONST_EVAL_TYPE_BOOL_NUM_STRING",
}
targets = sys.argv[1:] or ["lib", "test"]


def errors():
    out = subprocess.run(
        [DART, "analyze", "--format=machine", *targets],
        cwd=ROOT, capture_output=True, text=True,
    ).stdout + ""
    res = []
    for line in out.splitlines():
        parts = line.split("|")
        if len(parts) < 8 or parts[0] != "ERROR":
            continue
        code, path, ln, col = parts[2], parts[3], int(parts[4]), int(parts[5])
        res.append((code, path, ln, col))
    return res


for round_ in range(30):
    errs = errors()
    const_errs = [e for e in errs if e[0] in CODES]
    print(f"round {round_}: {len(errs)} errors, {len(const_errs)} const")
    if not const_errs:
        for e in errs[:20]:
            print("  ", e)
        break
    by_file = {}
    for code, path, ln, col in const_errs:
        by_file.setdefault(path, []).append((ln, col, code))
    for path, items in by_file.items():
        src = open(path, encoding="utf-8").read()
        lines = src.split("\n")
        starts = [0]
        for l in lines:
            starts.append(starts[-1] + len(l) + 1)
        done = set()
        # Work from the end so earlier offsets stay valid.
        for ln, col, code in sorted(items, reverse=True):
            off = starts[ln - 1] + col - 1
            # The nearest `const` before the error.
            m = None
            for mm in re.finditer(r"\bconst\b", src[:off]):
                m = mm
            if m is None or m.start() in done:
                continue
            done.add(m.start())
            before = src[: m.start()]
            line_start = before.rfind("\n") + 1
            prefix = src[line_start: m.start()]
            # A declaration (`static const double x = …`, top-level const):
            # becomes final. Otherwise drop the keyword.
            if re.fullmatch(r"\s*(static\s+)?", prefix) and re.match(
                r"const\s+[\w<>?, ]+\s+\w+\s*=|const\s+\w+\s*=", src[m.start():]
            ):
                src = src[: m.start()] + "final" + src[m.end():]
            else:
                end = m.end()
                if src[end:end + 1] == " ":
                    end += 1
                src = src[: m.start()] + src[end:]
        open(path, "w", encoding="utf-8", newline="\n").write(src)
