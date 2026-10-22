#!/usr/bin/env python3
"""Deletes the messages of a notmuch query for good: their files in a Trash folder are removed.

    erase.py QUERY      e.g. erase.py 'path:example/** and folder:/Trash$/'

Only files in a folder named Trash are touched, whatever the query matches, so a wrong query can't reach the inbox.
The sync tool (mbsync's Expunge Both) then deletes them on the server too. There is no undo.
Prints {"erased": N} or {"error": "..."}.
"""

import json
import os
import subprocess
import sys

FOLDER = "Trash"


def main():
    files = subprocess.run(["notmuch", "search", "--output=files", "--exclude=false", sys.argv[1]],
                           capture_output=True, text=True, check=True).stdout.split("\n")
    erased = 0
    for path in filter(None, files):
        # …/<account>/Trash/{cur,new}/<file>
        if os.path.basename(os.path.dirname(os.path.dirname(path))) != FOLDER or not os.path.exists(path):
            continue
        os.remove(path)
        erased += 1
    if erased:
        subprocess.run(["notmuch", "new", "--quiet", "--no-hooks"], check=True)
    print(json.dumps({"erased": erased}))


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, OSError) as e:
        print(json.dumps({"error": str(e)}))
