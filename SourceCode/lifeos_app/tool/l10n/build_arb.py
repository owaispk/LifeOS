"""Generates lib/l10n/app_en.arb and app_ur.arb from the strings_*.py pairs.

Run: python tool/l10n/build_arb.py   (then `flutter gen-l10n`)
Every key lives in exactly one strings_*.py file as (English, Urdu).
The Urdu copy is a first translation pending native-speaker review.
"""
import glob
import importlib.util
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "lib", "l10n")

merged = {}
for path in sorted(glob.glob(os.path.join(HERE, "strings_*.py"))):
    spec = importlib.util.spec_from_file_location(os.path.basename(path)[:-3], path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    for k, v in mod.S.items():
        if k in merged:
            raise SystemExit(f"duplicate key {k} in {path}")
        merged[k] = v


def placeholders(text):
    # Top-level {name} and plural selectors {n, plural, ...}.
    names = []
    depth = 0
    i = 0
    while i < len(text):
        c = text[i]
        if c == "{":
            if depth == 0:
                m = re.match(r"\{(\w+)", text[i:])
                if m and m.group(1) not in names:
                    names.append(m.group(1))
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return names


def build(index):
    arb = {"@@locale": ["en", "ur"][index]}
    for key in sorted(merged):
        text = merged[key][index]
        arb[key] = text
        if index == 0:
            ph = placeholders(text)
            if ph:
                meta = {}
                for p in ph:
                    plural = re.search(r"\{" + p + r",\s*plural", text)
                    meta[p] = {"type": "int"} if plural else {"type": "String"}
                arb["@" + key] = {"placeholders": meta}
    return arb


os.makedirs(OUT, exist_ok=True)
for i, loc in enumerate(["en", "ur"]):
    with open(os.path.join(OUT, f"app_{loc}.arb"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(build(i), f, ensure_ascii=False, indent=2)
        f.write("\n")
print(f"{len(merged)} keys")
