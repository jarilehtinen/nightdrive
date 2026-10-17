# AirDrop

Files and links from iPhones, iPads and Macs, as AirDrop. AirDrop doesn't use your Wi-Fi network but AWDL, Apple's own direct Wi-Fi link, and the Wi-Fi chip in M1 and M2 Macs already speaks it in its firmware. The installer brings a patched Wi-Fi driver from omdrop-awdl that lets Linux use it; Nightdrive's own receiver (`~/.config/hypr/scripts/airdrop receive`) answers the phone and asks before anything is saved, as LocalSend does. Set the phone to **Everyone for 10 minutes**: a phone set to Contacts Only can't see this computer.

**Status (17 October 2026): parked in this branch.** On a MacBook with the BCM4388 chip the receiver showed up on an iPhone once, but the link's transmit side stalls: the phone's connections arrive and the answers never reach it, so the computer mostly doesn't show up. Sending to an iPhone (omdrop-awdl's `send-to-peer`) never got through. It waits here for better support in omdrop-awdl.

The driver is built for the running kernel and again after every kernel update. If a build ever fails, the kernel's own driver loads instead: AirDrop stops, the Wi-Fi keeps working. Restart after installing.

The Wi-Fi uses the computer's own hardware address on every network instead of a different one per network (Fedora's default), because AWDL's address is derived from it. Networks can then recognise the computer from one to another, as with a Mac.

Remove everything with `./install-airdrop.sh --remove` in the Nightdrive folder, then restart.

Homepage: https://github.com/netmojo-systems/omdrop-awdl
Needs: a MacBook with M1 or M2 (Broadcom Wi-Fi)
