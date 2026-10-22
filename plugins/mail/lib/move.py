#!/usr/bin/env python3
"""Moves the messages of a notmuch query to a sibling folder of the one they are in (the account's Trash, Archive …).

    move.py FOLDER QUERY      e.g. move.py Trash thread:0000000000000005

Each file moves from <account>/<folder>/{cur,new}/ to <account>/FOLDER/cur/, without the ,U= (UID) part of its name
so the sync tool uploads it as a new message there and removes it from where it was. Files already in FOLDER stay.
Prints {"moved": N, "ids": [the query's message ids]} (for undo) or {"error": "..."}.
"""

import json
import os
import re
import subprocess
import sys


def main():
    folder, query = sys.argv[1], sys.argv[2]
    ids = subprocess.run(["notmuch", "search", "--output=messages", "--exclude=false", query],
                         capture_output=True, text=True, check=True).stdout.split()
    files = subprocess.run(["notmuch", "search", "--output=files", "--exclude=false", query],
                           capture_output=True, text=True, check=True).stdout.split("\n")
    moved = 0
    for path in filter(None, files):
        sub = os.path.dirname(path)                   # …/<account>/<folder>/cur
        account = os.path.dirname(os.path.dirname(sub))
        if os.path.basename(os.path.dirname(sub)) == folder or not os.path.exists(path):
            continue
        dest = os.path.join(account, folder, "cur")
        os.makedirs(dest, exist_ok=True)
        name = re.sub(r",U=\d+", "", os.path.basename(path))
        if ":2," not in name:                         # a message from new/ gets its flags part in cur/
            name += ":2,S"
        os.rename(path, os.path.join(dest, name))
        moved += 1
    if moved:
        subprocess.run(["notmuch", "new", "--quiet", "--no-hooks"], check=True)
    print(json.dumps({"moved": moved, "ids": [i.removeprefix("id:") for i in ids]}))


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, OSError) as e:
        print(json.dumps({"error": str(e)}))
