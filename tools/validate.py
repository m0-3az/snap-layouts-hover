#!/usr/bin/env python3
"""Validate the KWin script package before it is built.

Checks that the metadata is complete, the config files are well-formed
XML, the main script exists and the development switch is off.
"""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent / "package"


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def main():
    meta_path = ROOT / "metadata.json"
    if not meta_path.is_file():
        fail("package/metadata.json is missing")
    try:
        meta = json.loads(meta_path.read_text())
    except json.JSONDecodeError as e:
        fail(f"metadata.json is not valid JSON: {e}")

    if meta.get("KPackageStructure") != "KWin/Script":
        fail("KPackageStructure must be KWin/Script")

    plugin = meta.get("KPlugin", {})
    for key in ("Id", "Name", "Version", "License"):
        if not plugin.get(key):
            fail(f"KPlugin.{key} is missing")

    if meta.get("X-Plasma-API") != "declarativescript":
        fail("X-Plasma-API must be declarativescript")

    main_script = meta.get("X-Plasma-MainScript")
    if not main_script:
        fail("X-Plasma-MainScript is missing")
    main_path = ROOT / "contents" / main_script
    if not main_path.is_file():
        fail(f"main script not found: contents/{main_script}")

    for rel in ("contents/config/main.xml", "contents/ui/config.ui"):
        path = ROOT / rel
        if not path.is_file():
            fail(f"{rel} is missing")
        try:
            ET.parse(path)
        except ET.ParseError as e:
            fail(f"{rel} is not valid XML: {e}")

    qml = main_path.read_text()
    if "readonly property bool devShow: true" in qml:
        fail("devShow is enabled in main.qml")

    print(f"ok: {plugin['Id']} {plugin['Version']}")
    print("ok: metadata, config and main script")


if __name__ == "__main__":
    main()
