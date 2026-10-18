# LocalSend

Send files, photos and links from your phone to this computer with the free LocalSend app (iPhone and Android), and back. No cable, no account and no cloud: everything stays on your local network.

- Nightdrive answers LocalSend's discovery on its own, so the computer shows up in the phone's LocalSend under its name (launcher › Settings › Computer name). The LocalSend desktop app isn't needed.
- Every send asks first: a notification with Accept and Decline. Nothing is saved without Accept, and no answer in a minute is a Decline.
- Files go to your Downloads folder. A text or a shared link shows in the notification, with a Copy button.
- To the phone: right-click files or folders in Files › Send with LocalSend, or in the launcher Tools › Send clipboard with LocalSend or Send files with LocalSend. With several devices around, you pick one from a list. LocalSend has to be open on the phone, which asks before it saves anything (iOS doesn't let it listen in the background).
- The connection is encrypted: HTTPS with a certificate made on the first run, as LocalSend does.

**In a terminal**: `localsend send FILE…` sends files or folders, `localsend send-clipboard` the clipboard's text, and `localsend devices` lists the devices on the network.

Experimental. Turn it off with `localsend disable`.

Homepage: https://localsend.org
Needs: the LocalSend app on the phone, both on the same network
