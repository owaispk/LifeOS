"""Lists user-facing string literals still hard-coded in lib/ (PBI-025 AC2).

Same rule as test/l10n_test.dart: a string literal (with at least one
letter outside ${...}) passed straight to Text(...) or to a UI argument.
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "lib"))
ARGS = r"(?:label|title|tooltip|hintText|labelText|helperText|message|actionLabel|semanticsLabel|semanticLabel|subtitle|helpText|prefixText|suffixText|errorText|counterText|deleteButtonTooltipMessage|confirmText|cancelText)"
STR = r"""(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")"""
PAT = re.compile(r"(?:\bText\(\s*|\b" + ARGS + r":\s*(?:const\s+)?(?:Text\(\s*)?)(" + STR + r"(?:\s*" + STR + r")*)", re.S)


def has_words(lit):
    body = re.sub(r"\$\{[^}]*\}|\$\w+", "", lit)
    return re.search(r"[A-Za-z؀-ۿ]", body[1:-1] if len(body) > 1 else body) is not None


total = 0
by_file = {}
for d, _, files in os.walk(ROOT):
    if os.path.relpath(d, ROOT).split(os.sep)[0] == "l10n":
        continue
    for f in files:
        if not f.endswith(".dart") or f.endswith(".g.dart"):
            continue
        path = os.path.join(d, f)
        src = open(path, encoding="utf-8").read()
        for m in PAT.finditer(src):
            lit = m.group(1)
            if has_words(lit):
                line = src.count("\n", 0, m.start()) + 1
                by_file.setdefault(os.path.relpath(path, ROOT), []).append((line, lit.replace("\n", " ")[:80]))
                total += 1
for f in sorted(by_file, key=lambda k: -len(by_file[k])):
    print(f"{len(by_file[f]):4d}  {f}")
    if "-v" in sys.argv:
        for line, lit in by_file[f]:
            print(f"        {line}: {lit}")
print("TOTAL", total)
