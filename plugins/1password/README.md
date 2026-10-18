# 1Password

Your passwords at hand without opening the 1Password window: the app and its `op` command line tool, set up for Nightdrive.

- Launcher › Passwords: search your items, and Enter copies the password, Shift+Enter the username and Ctrl+Enter the one-time code. A copied password leaves the clipboard after 45 seconds and stays out of its history.
- ⌘⇧P brings up the 1Password window. It floats in the centre and is hidden from screen sharing.
- 1Password starts hidden at login (launcher › Settings › Startup), because the Passwords level and its SSH agent need it running.
- The SSH agent keeps your SSH keys in 1Password for Git and ssh: turn it on in 1Password › Settings › Developer.

**Setting up**: the installer gets the app from 1Password's own download for this machine, checking its signature, and the CLI from 1Password's repository. Then unlock 1Password and turn on Settings › Developer › Integrate with 1Password CLI, which the Passwords level needs. For Firefox, add the 1Password extension from addons.mozilla.org.

Homepage: https://1password.com
Needs: a 1Password account
Keys: ⌘⇧P
