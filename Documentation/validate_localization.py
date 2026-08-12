#!/usr/bin/env python3
"""Validate BilLandar's eight-language string catalogs.

This is intentionally dependency-free so it can run in CI and before an
archive. It checks both the app and widget catalogs, duplicate JSON keys,
non-empty translations, and preservation of format placeholders.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("en", "de", "es", "fr", "ja", "ko", "zh-Hans", "zh-Hant")
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|f|s|@)|\$\{[^}]+\}")


def normalized_placeholders(value: str) -> list[str]:
    """Ignore printf argument positions; translators may reorder them."""
    return sorted(re.sub(r"%(\d+\$)", "%", token) for token in PLACEHOLDER.findall(value))


def load_catalog(path: Path) -> dict:
    duplicates: list[str] = []

    def pairs(pairs: list[tuple[str, object]]) -> dict:
        result: dict = {}
        for key, value in pairs:
            if key in result:
                duplicates.append(key)
            result[key] = value
        return result

    with path.open(encoding="utf-8") as handle:
        catalog = json.load(handle, object_pairs_hook=pairs)
    if duplicates:
        raise ValueError(f"{path}: duplicate keys: {sorted(set(duplicates))}")
    return catalog


def validate(path: Path) -> list[str]:
    catalog = load_catalog(path)
    errors: list[str] = []
    for key, entry in catalog.get("strings", {}).items():
        # Xcode keeps an empty source key for a few generated format entries.
        if not key:
            continue
        source = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value", key)
        source_placeholders = normalized_placeholders(source)
        # English is the catalog source language; Xcode does not require a
        # duplicated `en` localization entry for every source key.
        for locale in LOCALES[1:]:
            value = entry.get("localizations", {}).get(locale, {}).get("stringUnit", {}).get("value", "")
            if not value:
                errors.append(f"{path.name}: {locale}: missing {key!r}")
                continue
            if normalized_placeholders(value) != source_placeholders:
                errors.append(f"{path.name}: {locale}: placeholder mismatch for {key!r}")
    return errors


def main() -> int:
    errors: list[str] = []
    for relative in ("BilLandar/Localizable.xcstrings", "BilLandarWidget/Localizable.xcstrings"):
        errors.extend(validate(ROOT / relative))
    if errors:
        print("Localization validation failed:")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("Localization validation passed: app and widget cover en, de, es, fr, ja, ko, zh-Hans, zh-Hant.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
