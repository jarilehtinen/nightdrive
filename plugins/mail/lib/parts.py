#!/usr/bin/env python3
"""Attachments of a message being read: open one, or save it.

    parts.py open MSGID PART NAME    copies the part to ~/.cache/nightmail/parts/ and prints {"path": ...} to open
    parts.py save MSGID PART NAME    copies it to the downloads folder, next to what is there, and prints {"path": ...}
    parts.py save-all MSGID PART NAME [PART NAME …]
                                     the same for each, and prints {"paths": [...]}

PART is notmuch's part number (`notmuch show --format=json` lists them), NAME the attachment's file name.
Failures are {"error": "..."}.
"""

import hashlib
import json
import os
import subprocess
import sys

PARTS = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "nightmail", "parts")


def downloads():
    try:
        d = subprocess.run(["xdg-user-dir", "DOWNLOAD"], capture_output=True, text=True).stdout.strip()
    except OSError:
        d = ""
    return d if d and d != os.path.expanduser("~") else os.path.expanduser("~/Downloads")


def free(folder, name):
    """A path in folder that takes nothing over: name, then name (2), name (3) …"""
    stem, ext = os.path.splitext(name)
    path, n = os.path.join(folder, name), 2
    while os.path.exists(path):
        path, n = os.path.join(folder, f"{stem} ({n}){ext}"), n + 1
    return path


def write(cmd, msgid, part, name):
    name = os.path.basename(name) or "attachment"
    data = subprocess.run(["notmuch", "show", "--format=raw", "--part=" + part, f'id:"{msgid}"'],
                          capture_output=True, check=True).stdout
    if cmd == "open":
        folder = os.path.join(PARTS, hashlib.sha1(msgid.encode()).hexdigest()[:12])
        path = os.path.join(folder, name)
    else:
        folder = downloads()
        path = free(folder, name)
    os.makedirs(folder, exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data)
    return path


def main():
    cmd, msgid = sys.argv[1:3]
    if cmd == "save-all":
        pairs = sys.argv[3:]
        print(json.dumps({"paths": [write("save", msgid, pairs[i], pairs[i + 1]) for i in range(0, len(pairs) - 1, 2)]}))
    else:
        print(json.dumps({"path": write(cmd, msgid, sys.argv[3], sys.argv[4])}))


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, OSError, ValueError) as e:
        print(json.dumps({"error": str(e)}))
