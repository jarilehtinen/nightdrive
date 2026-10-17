# Ferry

A mailbox between this computer and your iPhone (or any phone). Either end leaves photos, files, text or a link in the box, and they wait there until the other end picks them up. Unlike LocalSend, the phone needs no app, and the two don't have to be on the same network: Ferry goes over Tailscale, so it works from anywhere.

![Ferry's menu in the top bar](../screenshots/ferry.jpg)

- On the computer: drop files on the inbox icon in the top bar (holding them over it opens its menu, where you can drop them too), or press Send Clipboard in the menu. The menu lists both directions: a click copies a text or opens a file, a file can be dragged out into another app, and × takes an item out of the box.
- On the phone: a web page you add to the Home Screen. It sends photos, files and text (or the clipboard) to the computer, and gets what the computer left there: Copy for a text, Save for a file (the share sheet, with Save Image for a photo).
- A notification on the computer when the phone sends something, and on the phone when the computer does (Web Push: on an iPhone with iOS 16.4 or later, for the Home Screen app).
- Files from the phone go to your Downloads folder. Everything leaves the box after 7 days; removing an item doesn't delete a file from Downloads.

Only you can use it: the page answers only the Tailscale user who owns this computer, even if others share your tailnet. It works while the computer is awake and both ends are on Tailscale; when it can't reach the computer, the page says so.

**On the iPhone**: open the address shown at the bottom of Ferry's menu (or scan its QR code) in Safari, then Share › Add to Home Screen. Open Ferry from the Home Screen and tap Turn on notifications. The first time, Tailscale may need to be allowed to share the computer: if the menu says so, run `sudo tailscale set --operator=$USER` once and turn Ferry on again (`~/.config/hypr/scripts/ferry enable`).

Experimental. Turn it off with `~/.config/hypr/scripts/ferry disable`.

Needs: the Tailscale plugin, logged in on the computer and on the phone, with HTTPS turned on for the tailnet (Tailscale's admin console › DNS › HTTPS Certificates)
