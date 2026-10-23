#!/usr/bin/env python3
"""Fail if native UI translations drift from the Chinese source keys.

Web-shell content is intentionally excluded: only native Swift/UI, App Intents,
notifications and Info.plist privacy strings are audited.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCE = ROOT / "GTIIT" / "Resources"
SWIFT = sorted((ROOT / "GTIIT").rglob("*.swift"))
errors: list[str] = []


def unescape(value: str) -> str:
    return (value.replace(r"\n", "\n").replace(r"\t", "\t")
            .replace(r'\"', '"').replace(r"\\", "\\"))


def literal_keys(pattern: str, source: str) -> set[str]:
    return {unescape(m.group(1)) for m in re.finditer(pattern, source)}


def strings_table(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r'^"(.*)"\s*=\s*"(.*)";', line.strip())
        if match:
            result[match.group(1)] = match.group(2)
    return result


native = json.loads((RESOURCE / "CampusData" / "native-en.json").read_text(encoding="utf-8"))
keys: set[str] = set()
formatted: set[str] = set()
for path in SWIFT:
    text = path.read_text(encoding="utf-8")
    keys |= literal_keys(r'L10n\.tr\("((?:[^"\\]|\\.)*)"\)', text)
    formatted |= literal_keys(r'L10n\.format\("((?:[^"\\]|\\.)*)"', text)

for key in sorted(keys | formatted):
    if key not in native:
        errors.append(f"missing native-en key: {key!r}")
for key, value in native.items():
    if not value.strip():
        errors.append(f"empty native-en value: {key!r}")
    if re.search(r"[一-鿿]", value):
        errors.append(f"English native-en value contains Chinese: {key!r}")
for key in sorted(formatted & set(native)):
    zh_count = key.count("%@")
    en_count = native[key].count("%@")
    if zh_count != en_count:
        errors.append(f"format placeholder drift: {key!r} zh={zh_count} en={en_count}")

en = strings_table(RESOURCE / "en.lproj" / "Localizable.strings")
zh = strings_table(RESOURCE / "zh-Hans.lproj" / "Localizable.strings")
for lang, table in [("en", en), ("zh-Hans", zh)]:
    if not table:
        errors.append(f"{lang} Localizable.strings is empty")
if set(en) != set(zh):
    errors.append(f"Localizable.strings key drift: en-only={sorted(set(en) - set(zh))[:8]} zh-only={sorted(set(zh) - set(en))[:8]}")
for key in sorted(set(en) & set(zh)):
    if en[key].count("%@") != zh[key].count("%@"):
        errors.append(f"Localizable format drift: {key!r}")
    if zh[key] != en[key] and re.search(r"[\u4e00-\u9fff]", en[key]):
        errors.append(f"English Localizable value still contains Chinese: {key!r}")

plist = (ROOT / "GTIIT" / "Info.plist").read_text(encoding="utf-8")
usage_keys = set(re.findall(r"<key>(NS\w+UsageDescription)</key>", plist))
for lang in ("en", "zh-Hans"):
    path = RESOURCE / f"{lang}.lproj" / "InfoPlist.strings"
    table = strings_table(path)
    if not table:
        errors.append(f"{lang} InfoPlist.strings is empty")
    missing = sorted(usage_keys - set(table))
    if missing:
        errors.append(f"{lang} InfoPlist.strings missing: {missing}")
    for key in sorted(usage_keys & set(table)):
        if not table[key].strip():
            errors.append(f"{lang} InfoPlist value empty: {key}")
if set(strings_table(RESOURCE / "en.lproj" / "InfoPlist.strings")) != set(strings_table(RESOURCE / "zh-Hans.lproj" / "InfoPlist.strings")):
    errors.append("InfoPlist.strings key drift")

# User-facing hardcoded literals. Brand names and AppIntent/display metadata are
# allowed; everything else belongs in L10n or a localized resource.
allowed = {"GTIIT", "Moodle", "ALPHA", "CAMPUS IN MOTION", "YOUR CAMPUS, CONNECTED"}
for path in SWIFT:
    text = path.read_text(encoding="utf-8")
    for line_no, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("//"):
            continue
        for match in re.finditer(r'(?:Text|Label|Button)\("((?:[^"\\]|\\.)*)"', line):
            value = unescape(match.group(1))
            if value and value not in allowed and not value.startswith("%") and not value.startswith("\\("):
                errors.append(f"hardcoded UI literal {path.relative_to(ROOT)}:{line_no}: {value!r}")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)
print(f"localization ok: {len(keys)} tr keys, {len(formatted)} format keys, {len(en)} .strings, {len(usage_keys)} Info.plist keys")
