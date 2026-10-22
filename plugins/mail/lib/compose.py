#!/usr/bin/env python3
"""Writing side of Nightdrive Mail: reply templates, sending and drafts.

    compose.py account                 the account as JSON (name, address)
    compose.py reply MSGID [all]       a reply's fields as JSON: to, cc, subject, in_reply_to, references, body
    compose.py forward MSGID           a forward's fields as JSON: subject, body and the message's attachments
    compose.py resume MSGID            a saved draft's fields as JSON, to write on (draft_id is the draft)
    compose.py send JSON               send the message, then file a copy in Sent
    compose.py draft JSON              file the message in Drafts
    compose.py suggest MSGID [HINT]    Claude's reply to the thread up to MSGID, as {"text": ..., "read": messages read}
    compose.py write TEXT              Claude writes out TEXT (the selection) as a reply, reading nothing else: {"text"}

JSON holds to, cc, subject, body, attachments (file paths) and, for a reply, in_reply_to and references; draft_id is
the copy saved in Drafts before, which a new save or sending removes. A forward's or a draft's attachments are copied
out of the message into ~/.cache/nightmail/parts/ first, so a message is always built from files. Every command prints one JSON object;
failures are {"error": "..."}, so the window can show them.

The account is read from ~/.config/nightmail/account.conf:

    [account]
    name = Your Name
    address = you@example.com
    smtp = mail.example.com:465
    user = login@example.com
    password-cmd = secret-tool lookup service example user login@example.com
    sent = example/Sent
    drafts = example/Drafts
    suggest-model = sonnet            (optional: the Claude model that writes suggested replies)
"""

import configparser
import email
import email.policy
import hashlib
import json
import mimetypes
import os
import shlex
import smtplib
import subprocess
import sys
from email.message import EmailMessage
from email.utils import formataddr, formatdate, getaddresses, make_msgid, parseaddr, parsedate_to_datetime

CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "nightmail", "account.conf")
PARTS = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "nightmail", "parts")
SMTP_TIMEOUT = 30  # seconds
SUGGEST_TIMEOUT = 120  # seconds for Claude to write a reply
SUGGEST_PROMPT = """You write email replies for {name} <{address}>. You get an email thread, oldest message first.
Write {first}'s reply to the last message. Use the language of the last message. Sound like a person: short, warm, to
the point, no filler, no subject line, no quote of the thread, no placeholders unless a fact is truly missing (then
[like this]). End with the sign-off "{first}" on its own line. Output only the reply's text."""


def account():
    cp = configparser.ConfigParser()
    if not cp.read(CONFIG):
        raise SystemExit(json.dumps({"error": f"No account: {CONFIG} is missing"}))
    return cp["account"]


def plain_text(parts):
    for part in parts:
        if part.get("content-disposition") == "attachment":
            continue
        content = part.get("content")
        if isinstance(content, list):
            text = plain_text(content)
            if text:
                return text
        elif part.get("content-type", "").lower() == "text/plain" and content:
            return content
    return ""


def reply(msgid, to_all):
    out = subprocess.run(["notmuch", "reply", "--format=json", "--reply-to=" + ("all" if to_all else "sender"),
                          "id:" + msgid], capture_output=True, text=True, check=True).stdout
    data = json.loads(out)
    h, orig = data["reply-headers"], data["original"]
    when = parsedate_to_datetime(orig["headers"]["Date"]).strftime("%a %d %b %Y, %H:%M") if orig["headers"].get("Date") else ""
    name, addr = parseaddr(orig["headers"].get("From", ""))
    quoted = "\n".join(">" + line if line.startswith(">") else "> " + line if line else ">" for line in plain_text(orig.get("body", [])).rstrip().split("\n"))
    return {
        "to": h.get("To", ""),
        "cc": h.get("Cc", ""),
        "subject": h.get("Subject", ""),
        "in_reply_to": h.get("In-reply-to", ""),
        "references": h.get("References", ""),
        "body": f"\n\nOn {when}, {name or addr} wrote:\n{quoted}\n",
    }


def parsed(msgid):
    """The message as an email.message.EmailMessage, read from its file."""
    files = subprocess.run(["notmuch", "search", "--output=files", "--exclude=false", f'id:"{msgid}"'],
                           capture_output=True, text=True, check=True).stdout.split("\n")
    with open(next(p for p in files if p and os.path.exists(p)), "rb") as fh:
        return email.message_from_binary_file(fh, policy=email.policy.default)


def attachments(msgid, msg):
    """Copies the message's attachments to files of their own and returns their paths."""
    folder = os.path.join(PARTS, hashlib.sha1(msgid.encode()).hexdigest()[:12])
    paths = []
    for part in msg.iter_attachments():
        name = os.path.basename(part.get_filename() or "") or "attachment" + (mimetypes.guess_extension(part.get_content_type()) or "")
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, name)
        with open(path, "wb") as fh:
            fh.write(part.get_payload(decode=True) or b"")
        paths.append(path)
    return paths


def body_text(msg):
    part = msg.get_body(preferencelist=("plain",))
    return part.get_content() if part else ""


def forward(msgid):
    msg = parsed(msgid)
    subject = str(msg.get("Subject", ""))
    header = "\n".join(f"{k}: {msg[k]}" for k in ("From", "Date", "Subject", "To", "Cc") if msg.get(k))
    return {
        "subject": subject if subject.lower().startswith(("fwd:", "fw:")) else "Fwd: " + subject,
        "body": f"\n\n---------- Forwarded message ----------\n{header}\n\n{body_text(msg).rstrip()}\n",
        "attachments": attachments(msgid, msg),
    }


def resume(msgid):
    msg = parsed(msgid)
    return {
        "to": str(msg.get("To", "")),
        "cc": str(msg.get("Cc", "")),
        "subject": str(msg.get("Subject", "")),
        "in_reply_to": str(msg.get("In-Reply-To", "")),
        "references": str(msg.get("References", "")),
        "body": body_text(msg),
        "attachments": attachments(msgid, msg),
        "draft_id": msgid,
    }


def build(acc, f):
    msg = EmailMessage()
    msg["From"] = formataddr((acc.get("name", ""), acc["address"]))
    msg["To"] = f.get("to", "")
    if f.get("cc"):
        msg["Cc"] = f["cc"]
    msg["Subject"] = f.get("subject", "")
    msg["Date"] = formatdate(localtime=True)
    msg["Message-ID"] = make_msgid(domain=acc["address"].split("@")[-1])
    if f.get("in_reply_to"):
        msg["In-Reply-To"] = f["in_reply_to"]
        msg["References"] = f.get("references") or f["in_reply_to"]
    msg["User-Agent"] = "Nightdrive Mail"
    msg.set_content(f.get("body", ""))
    for path in f.get("attachments") or []:
        kind = mimetypes.guess_type(path)[0] or "application/octet-stream"
        with open(path, "rb") as fh:
            msg.add_attachment(fh.read(), *kind.split("/", 1), filename=os.path.basename(path))
    return msg


def file_in(folder, msg, tags):
    subprocess.run(["notmuch", "insert", "--folder=" + folder, "--create-folder", "-inbox", "-unread"] + tags,
                   input=msg.as_bytes(), check=True)


def send(f):
    acc = account()
    msg = build(acc, f)
    rcpts = [a for _, a in getaddresses([f.get("to", ""), f.get("cc", "")]) if a]
    if not rcpts:
        return {"error": "No recipient"}
    host, _, port = acc["smtp"].partition(":")
    password = subprocess.run(shlex.split(acc["password-cmd"]), capture_output=True, text=True, check=True).stdout.strip()
    port = int(port or 465)
    if port == 465:
        server = smtplib.SMTP_SSL(host, port, timeout=SMTP_TIMEOUT)
    else:
        server = smtplib.SMTP(host, port, timeout=SMTP_TIMEOUT)
        server.starttls()
    with server:
        server.login(acc.get("user", acc["address"]), password)
        server.send_message(msg, to_addrs=rcpts)
    file_in(acc["sent"], msg, ["+sent"])
    drop(f.get("draft_id"))
    return {"ok": True, "id": msg["Message-ID"].strip("<>")}


def drop(msgid):
    """Removes an earlier saved draft (replaced by a newer save, or sent)."""
    if not msgid:
        return
    files = subprocess.run(["notmuch", "search", "--output=files", "--exclude=false", f'id:"{msgid}"'],
                           capture_output=True, text=True, check=True).stdout.split("\n")
    for path in filter(None, files):
        if os.path.exists(path):
            os.remove(path)
    subprocess.run(["notmuch", "new", "--quiet", "--no-hooks"], check=True)


def draft(f):
    """Files the message in Drafts, in place of the copy saved before (draft_id)."""
    acc = account()
    msg = build(acc, f)
    file_in(acc["drafts"], msg, ["+draft"])
    drop(f.get("draft_id"))
    return {"ok": True, "id": msg["Message-ID"].strip("<>")}


def thread_text(msgid):
    out = subprocess.run(["notmuch", "show", "--format=json", "--entire-thread=true", "id:" + msgid],
                         capture_output=True, text=True, check=True).stdout
    msgs = []

    def walk(node):
        for n in node:
            if isinstance(n, list) and len(n) == 2 and isinstance(n[0], dict) and "headers" in n[0]:
                msgs.append(n[0])
                walk(n[1])
            elif isinstance(n, list):
                walk(n)
    walk(json.loads(out))
    parts = []
    for m in msgs:
        h = m["headers"]
        # Quoted lines repeat earlier messages, which are in the thread already.
        body = "\n".join(l for l in plain_text(m.get("body", [])).split("\n") if not l.startswith(">")).strip()
        parts.append(f"From: {h.get('From', '')}\nDate: {h.get('Date', '')}\nSubject: {h.get('Subject', '')}\n\n{body}")
        if m["id"] == msgid:
            break
    return "\n\n---\n\n".join(parts), len(parts)


def ask_claude(system, text):
    acc = account()
    # No tools and no saved session: Claude only writes the text.
    cmd = ["claude", "-p", "--tools", "", "--no-session-persistence", "--system-prompt", system,
           "--model", acc.get("suggest-model", "sonnet")]
    return subprocess.run(cmd, input=text, capture_output=True, text=True, check=True,
                          timeout=SUGGEST_TIMEOUT, cwd=os.path.expanduser("~")).stdout.strip()


def prompt():
    acc = account()
    name = acc.get("name", "")
    first = name.split()[0] if name else acc["address"].split("@")[0]
    return SUGGEST_PROMPT.format(name=name, address=acc["address"], first=first), first


def suggest(msgid, hint):
    """The reply, from the whole thread up to msgid (and the draft, if any)."""
    system, first = prompt()
    if hint:
        system += (f"\n\n{first} has drafted the reply: notes, bullet points or part of it. Write it out as the full reply, "
                   f"keeping everything it says and its tone. The draft:\n\n{hint}")
    thread, read = thread_text(msgid)
    out = ask_claude(system, thread)
    return {"text": out, "read": read} if out else {"error": "Claude wrote nothing"}


def write(text):
    """The reply from the selected text alone: the thread stays on this computer."""
    system, first = prompt()
    # The thread part of the prompt doesn't apply: there is only the selection.
    system = system.replace("You get an email thread, oldest message first.", "").replace("the last message", "the text")
    system += (f"\n\nYou don't get the thread, only what {first} selected: notes, a draft or a part of the email. Write it "
               "out as the finished reply, keeping everything it says and its tone; if it is a message to answer, answer it.")
    out = ask_claude(system, text)
    return {"text": out} if out else {"error": "Claude wrote nothing"}


def main():
    cmd, args = sys.argv[1], sys.argv[2:]
    try:
        if cmd == "account":
            acc = account()
            result = {"name": acc.get("name", ""), "address": acc["address"]}
        elif cmd == "reply":
            result = reply(args[0], len(args) > 1 and args[1] == "all")
        elif cmd == "forward":
            result = forward(args[0])
        elif cmd == "resume":
            result = resume(args[0])
        elif cmd == "send":
            result = send(json.loads(args[0]))
        elif cmd == "suggest":
            result = suggest(args[0], " ".join(args[1:]))
        elif cmd == "write":
            result = write(args[0])
        elif cmd == "draft":
            result = draft(json.loads(args[0]))
        else:
            result = {"error": "Unknown command " + cmd}
    except subprocess.CalledProcessError as e:
        result = {"error": f"{e.cmd[0]} failed: {(e.stderr or '').strip() or e.returncode}"}
    except StopIteration:
        result = {"error": "The message's file is missing: sync, then try again"}
    except subprocess.TimeoutExpired:
        result = {"error": "Claude took too long"}
    except (smtplib.SMTPException, OSError) as e:
        result = {"error": f"Sending failed: {e}"}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
