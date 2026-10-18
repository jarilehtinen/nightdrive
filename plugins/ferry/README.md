# Ferry

A mailbox between your computers and your phone. Leave photos, files, text or a link at one end, and pick them up at the other. The phone needs no app, and the two don't have to be on the same network: Ferry goes over Tailscale, so it works from anywhere.

![Ferry's menu in the top bar](ferry.jpg)

- On the computer: drop files on the inbox icon in the top bar or in its menu, or press Send Clipboard. The menu lists what your other devices sent: a click copies a text or opens a file, and a file drags out into another app.
- On the phone: a page on the Home Screen. Received has what your computers sent, ready to copy or save; Send takes text, the clipboard, photos and files.
- With Ferry on several computers, the phone sees them all on one page and picks where each send goes.
- Each end gets a notification when the other sends something.
- Files from the phone go to Downloads. Everything leaves the box after 7 days.

**Adding the phone**: press Add Device in Ferry's menu, scan the QR code (or open the address) in the phone's browser and add the page to the Home Screen. Open Ferry from there and tap Turn on notifications. If the menu says Tailscale needs permission, run `sudo tailscale set --operator=$USER` once, then `ferry enable`.

**In a terminal**: `ferry send FILE…` sends files (or a text, or with nothing the clipboard), `ferry list` shows the box, and `ferry get` saves the newest item from the phone. `ferry help` lists the rest.

**Who can get in**: only you. The page isn't on the internet (tailscale serve, not Funnel), and it answers only the Tailscale user who owns the computer. Nothing that arrives is opened or run by itself. The phone is the key: if it's lost unlocked, remove it in Tailscale's admin console. Ferry suits a computer that is yours alone, and its tailnet name (computer.tailXXXX.ts.net) shows in public certificate logs.

Needs: the Tailscale plugin on the computer and the phone, with HTTPS certificates turned on for the tailnet (Tailscale's admin console › DNS)
