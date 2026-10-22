# Mail

A quiet mail client: folders, the thread list and the open thread, nothing else on screen. New mail arrives as a notification you can answer from, and Claude can write a reply for you to read before anything is sent. Your mail stays in a folder on your computer (fetched with mbsync, searched with notmuch), so it opens at once and works offline.

## Reading

- Hold ⌘ (or press `?`) in Mail to see its keys. The ⌘ keys follow Mac Mail; on a PC keyboard they are Ctrl (Ctrl+R, Ctrl+N…), as in Thunderbird and Outlook.
- `j` / `k` or ⌥↑ / ⌥↓ move in the list, the arrows scroll the message, `Space` and ⇧Space page through it. `/` or ⌘F searches (notmuch's query syntax), `Esc` clears the search.
- `1`–`6` or Ctrl+↑ / Ctrl+↓ pick a folder: Inbox, Sent, Drafts, Archive, Spam, Trash. ⌘B hides the folders.
- `h` shows a message as text, as HTML on the dark page, or as HTML on light paper as it was sent; which one comes first is a setting (text by default). Remote images stay off.
- `Enter` or a double click opens the thread in a window of its own (in Drafts, it goes on writing the draft). Opening an unread thread marks it read; `u` marks it unread again.
- `a` archives, `d` moves to Trash, `!` marks spam (in Spam: not spam, back to the Inbox), ⌘Z undoes them. The next sync makes the same move on the server, so your phone and webmail see it too.
- Attachments show under their message: a click opens one, Save puts it in Downloads.

## Writing

- `c` or ⌘N writes a new message, `r` replies to all, ⇧R to the sender only, `f` forwards (with the attachments).
- Writing opens in a window of its own: Ctrl+Enter sends, ⌘S saves it in Drafts. `Esc` closes it (a message saved before is saved again; with something new written, the second `Esc` throws it away). Closing the window with ⌘W keeps what you wrote in Drafts.
- To and Cc offer the addresses in your mail as you type, the ones you use most first: ↑ / ↓ choose, `Tab` or `Enter` takes one.
- ⌘⇧A or Attach picks files to attach, files dropped on the window are attached too, and × takes one off.
- Mail opens mailto: links when you pick it as the email app (launcher › Settings › Default apps): then Hyper E opens Mail too.

## Claude writes the reply

- ⌘⇧C on a message has Claude write the reply, in the message's language, signed with your first name. In the writing window, ⌘⇧C writes out what you started: select your draft (a start, a few points, "say yes, but next week") and Claude's reply takes its place.
- The reply shows first in a card by the mouse, with what Claude read: `Enter` puts it in place, ⌘⇧C writes another version, `Esc` cancels. Nothing is sent before you press Ctrl+Enter.
- What Claude reads is your choice, asked the first time you press ⌘⇧C: the whole thread (the best replies), or only the text you select, so the thread stays on your computer. Settings (⌘,) changes it later.
- It needs Claude Code signed in (`claude`): the reply is written by `claude -p` with no tools.

## Notifications

- New unread mail in the inbox gets a notification with Reply, Reply with Claude and Delete; a click opens the message in Mail. More than three at once come as one notification that counts them.
- They come after each sync even when Mail is closed: notmuch's post-new hook runs `nightmail notify`. A hook of your own is left alone; add `nightmail notify` to it yourself.

## Settings

⌘, (or Settings under the folders): whether writing and message windows float (the default) or open in the grid beside Mail, how a message opens (text, HTML on the dark page, or HTML as it was sent), and what Claude reads. They are kept in `~/.config/nightmail/settings.json`. Mail's colours follow the desktop's theme.

## Setting up an account

Mail reads the mail that mbsync has fetched into `~/Mail` and notmuch has indexed, and sends through your provider's SMTP server. These steps set up one account; each command can be run as it is, after putting your own values in place of the examples (you@example.com, mail.example.com, the account name `example`). Claude can do them with you: ask it to set up Nightdrive Mail by this page.

1. Install the plugin (launcher › System › Install › Plugins › Mail): it installs notmuch, isync (mbsync), libsecret (secret-tool) and zenity, and says what is still missing. Many providers want an app password for mail apps (Gmail, iCloud, Outlook, Fastmail): make one in the provider's account settings first.

2. Put the password in the login keyring, so it is never in a file (it asks for the password):

```
secret-tool store --label="Mail: you@example.com" service mail.example.com user you@example.com
```

3. Tell mbsync where the mail is: `~/.config/isyncrc`. The inbox goes in a folder named `INBOX`, and the others keep the server's names:

```
IMAPAccount example
Host mail.example.com
Port 993
TLSType IMAPS
User you@example.com
PassCmd "secret-tool lookup service mail.example.com user you@example.com"

IMAPStore example-remote
Account example

MaildirStore example-local
Path ~/Mail/example/
Inbox ~/Mail/example/INBOX
SubFolders Verbatim

Channel example
Far :example-remote:
Near :example-local:
Patterns *
Create Both
Expunge Both
SyncState *
```

4. Tell notmuch where the index is: `~/.config/notmuch/default/config` (write your name and address):

```
[database]
path=Mail
[user]
name=Your Name
primary_email=you@example.com
[new]
tags=unread;inbox;
ignore=.mbsyncstate;.uidvalidity;.mbsyncstate.journal;.mbsyncstate.new;.mbsyncstate.lock
[search]
exclude_tags=deleted;spam;
[maildir]
synchronize_flags=true
```

5. Fetch the mail and index it. The first time takes a while with a big mailbox:

```
mkdir -p ~/Mail/example
mbsync -a
notmuch new
```

6. Tell Mail how to send: `~/.config/nightmail/account.conf`. `sent` and `drafts` are the folders under `~/Mail` that mbsync made (a copy of each sent message goes there, and the next sync uploads it). `suggest-model` is optional: the Claude model that writes replies (sonnet by default).

```
[account]
name = Your Name
address = you@example.com
smtp = mail.example.com:465
user = you@example.com
password-cmd = secret-tool lookup service mail.example.com user you@example.com
sent = example/Sent
drafts = example/Drafts
```

7. Run the plugin's installer again (or `nightmail enable`): Mail joins the apps, the notifications get their hook, and the sync runs every 5 minutes. What is in the inbox now isn't announced as new.

8. Check it: `nightmail` opens Mail with your inbox. Send yourself a message, then `nightmail sync`: it shows in the inbox and a notification comes.

Mail finds the folders by these names: `INBOX`, `Sent`, `Drafts`, `Archive`, `Spam` and `Trash` (Archive is made the first time you archive). Runbox and Fastmail use them as they are. Where the server's names differ, map them to Mail's in `isyncrc` with a channel per folder in place of `Patterns *`: Gmail's `[Gmail]/Sent Mail`, `[Gmail]/Drafts`, `[Gmail]/Spam` and `[Gmail]/Trash`, iCloud's `Sent Messages`, `Junk` and `Deleted Messages`, Outlook's `Sent Items`, `Junk Email` and `Deleted Items`. For example:

```
Channel example-sent
Far :example-remote:"[Gmail]/Sent Mail"
Near :example-local:Sent
Create Near
Expunge Both
SyncState *
```

Mail shows one account. More than one can be fetched into `~/Mail`, but sending, Sent and Drafts follow `account.conf`.

## In a terminal

| Command | What it does |
| --- | --- |
| `nightmail` | Opens Mail, or brings it forward |
| `nightmail new` | Writes a new message |
| `nightmail sync` | Fetches new mail now and shows it |
| `nightmail show ID`, `reply ID`, `claude ID`, `delete ID` | A message by its notmuch id, as the notifications use them |
| `nightmail enable`, `disable` | Mail among the apps, its notifications and the sync, on or off (your mail and settings stay) |
| `nightmail restart`, `quit`, `log` | After a change to Mail, and its QML errors |

Needs: notmuch, isync (mbsync), an IMAP account; Claude Code for Claude's replies
