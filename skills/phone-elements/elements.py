#!/data/data/com.termux/files/usr/bin/python3
"""Parse uiautomator XML dump and find elements by text, ID, or class.
Usage: python3 elements.py [--text "确认"] [--id "submit"] [--class "Button"] [--tap] [--dump-only]

Dual-channel: tries Shizuku rish first, falls back to ADB.
Outputs JSON with element bounds and center coordinates.
--tap: find and tap the first match automatically.
--dump-only: just dump the XML, don't parse.
"""

import subprocess, sys, os, json, xml.etree.ElementTree as ET

def run_dump():
    """Dump UI hierarchy via Shizuku or ADB, return raw XML text.

    Strategy (OEM-resilient):
    1. Try /dev/tty first (AOSP standard, no file I/O) — works on stock Android, Samsung, vivo newer models
    2. Fall back to file dump (more compatible: vivo older, Xiaomi MIUI)
    3. MIUI returns non-zero exit code even on success — we check XML content, not exit code
    """
    DUMP_PATH = "/sdcard/ui_dump.xml"

    def _try(channel_cmd):
        """channel_cmd is a list like ['rish','-c'] or ['adb','-s','127...','shell']"""
        try:
            # Method 1: /dev/tty (fast, no file I/O)
            r = subprocess.run(channel_cmd + ["uiautomator dump /dev/tty"],
                              capture_output=True, text=True, timeout=15)
            out = r.stdout.strip()
            # MIUI: exit code may be non-zero but XML still present
            if out:
                # Some devices prepend status line — strip to find XML
                xml_start = out.find("<?xml")
                if xml_start < 0:
                    xml_start = out.find("<hierarchy")
                if xml_start >= 0:
                    return out[xml_start:]

        except Exception:
            pass

        try:
            # Method 2: file dump (more compatible, e.g. vivo OriginOS)
            subprocess.run(channel_cmd + [f"uiautomator dump {DUMP_PATH}"],
                          capture_output=True, text=True, timeout=15)
            # Ignore exit code — MIUI bug: non-zero even with valid XML
            r2 = subprocess.run(channel_cmd + [f"cat {DUMP_PATH}"],
                               capture_output=True, text=True, timeout=10)
            out = r2.stdout.strip()
            if out and "<" in out:
                xml_start = out.find("<?xml")
                if xml_start < 0:
                    xml_start = out.find("<hierarchy")
                if xml_start >= 0:
                    return out[xml_start:]
        except Exception:
            pass
        return None

    # Try Shizuku first
    for cmd in [["rish", "-c"], ["adb", "-s", "127.0.0.1:5555", "shell"]]:
        result = _try(cmd)
        if result:
            return result

    print("Error: no shell channel available (Shizuku down, ADB not connected)", file=sys.stderr)
    sys.exit(1)

def parse_xml(xml_str):
    """Parse the XML and extract all clickable/meaningful nodes."""
    # uiautomator dump prepends "UI hierchary dumped to: /dev/tty" — strip it
    start = xml_str.find("<?xml")
    if start < 0:
        start = xml_str.find("<hierarchy")
    if start < 0:
        print("Error: no XML found in output", file=sys.stderr)
        sys.exit(1)
    xml_str = xml_str[start:]

    root = ET.fromstring(xml_str)
    elements = []

    def walk(node, depth=0):
        attrs = {
            "class": node.attrib.get("class", ""),
            "resource-id": node.attrib.get("resource-id", ""),
            "text": node.attrib.get("text", ""),
            "content-desc": node.attrib.get("content-desc", ""),
            "bounds": node.attrib.get("bounds", ""),
            "clickable": node.attrib.get("clickable", "false") == "true",
            "enabled": node.attrib.get("enabled", "true") == "true",
            "focusable": node.attrib.get("focusable", "false") == "true",
        }
        # Parse bounds "[left,top][right,bottom]" → center point
        b = node.attrib.get("bounds", "")
        if b:
            try:
                parts = b.replace("[", ",").replace("]", ",").split(",")
                parts = [int(x) for x in parts if x.strip()]
                if len(parts) == 4:
                    attrs["x"] = (parts[0] + parts[2]) // 2
                    attrs["y"] = (parts[1] + parts[3]) // 2
                    attrs["w"] = parts[2] - parts[0]
                    attrs["h"] = parts[3] - parts[1]
            except ValueError:
                pass

        # Only include meaningful nodes (visible, has bounds)
        if attrs.get("x") is not None:
            elements.append(attrs)
        for child in node:
            walk(child, depth + 1)

    walk(root)
    return elements

def find_elements(elements, text=None, rid=None, cls=None):
    """Filter elements by text, resource-id substring, or class substring."""
    results = elements
    if text:
        results = [e for e in results if text in e.get("text", "") or text in e.get("content-desc", "")]
    if rid:
        results = [e for e in results if rid in e.get("resource-id", "")]
    if cls:
        results = [e for e in results if cls.lower() in e.get("class", "").lower()]
    return results

def tap(x, y):
    """Tap at coordinates via Shizuku or ADB."""
    cmd = f"input tap {x} {y}"
    try:
        subprocess.run(["rish", "-c", cmd], timeout=5, capture_output=True)
        return True
    except Exception:
        pass
    try:
        subprocess.run(["adb", "-s", "127.0.0.1:5555", "shell", cmd], timeout=5, capture_output=True)
        return True
    except Exception:
        return False

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="Android UI element tree parser")
    p.add_argument("--text", help="Find elements containing this text")
    p.add_argument("--id", dest="rid", help="Find elements by resource-id substring")
    p.add_argument("--class", dest="cls", help="Find elements by class substring")
    p.add_argument("--tap", action="store_true", help="Tap the first match")
    p.add_argument("--dump-only", action="store_true", help="Just dump XML, don't parse")
    p.add_argument("--limit", type=int, default=10, help="Max results to show (default: 10)")
    args = p.parse_args()

    xml_str = run_dump()

    if args.dump_only:
        start = xml_str.find("<?xml")
        print(xml_str[start:] if start >= 0 else xml_str)
        sys.exit(0)

    elements = parse_xml(xml_str)
    results = find_elements(elements, text=args.text, rid=args.rid, cls=args.cls)

    if not results:
        print("[]")
        sys.exit(0)

    output = []
    for i, e in enumerate(results[:args.limit]):
        item = {
            "idx": i,
            "text": e["text"],
            "class": e["class"],
            "id": e["resource-id"],
            "x": e["x"], "y": e["y"],
            "w": e["w"], "h": e["h"],
            "clickable": e["clickable"],
        }
        output.append(item)

    print(json.dumps(output, ensure_ascii=False, indent=2))

    if args.tap and output:
        target = output[0]
        print(f"\nTapping ({target['x']}, {target['y']}) — '{target['text'] or target['id']}'", file=sys.stderr)
        if tap(target["x"], target["y"]):
            print("✓ Tapped.", file=sys.stderr)
        else:
            print("✗ Tap failed.", file=sys.stderr)
