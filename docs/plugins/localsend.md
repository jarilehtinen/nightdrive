# LocalSend

Send files, photos and links from your phone to this computer with the free LocalSend app (iPhone and Android). No cable, no account and no cloud: everything stays on your local network.

Nightdrive answers LocalSend's discovery on its own, so the computer shows up in the phone's LocalSend under its name. The LocalSend desktop app isn't needed.

- Every send asks first: a notification with Accept and Decline. Nothing is saved without Accept, and no answer in a minute is a Decline.
- Files go to your Downloads folder.
- A text or a shared link shows in the notification, with a Copy button.

Sending works the other way too: right-click files or folders in Files › Send with LocalSend, or in the launcher Tools › Send clipboard / Send files with LocalSend. The phone asks before it saves anything, so LocalSend has to be open there (iOS doesn't let it listen in the background). With several devices around, you pick one from a list.

The connection is encrypted (HTTPS with a certificate made on the first run, as LocalSend does). Turn it off again with `~/.config/hypr/scripts/localsend disable`.

Homepage: https://localsend.org
Needs: the LocalSend app on the phone, both on the same network
