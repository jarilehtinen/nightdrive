# AirDrop

AirDrop between this computer and iPhones, iPads and Macs. This is the first part, the radio: AirDrop doesn't use your Wi-Fi network but AWDL, Apple's own direct Wi-Fi link, and the Wi-Fi chip in M1 and M2 Macs already speaks it in its firmware. The installer brings a patched Wi-Fi driver from omdrop-awdl that lets Linux use it. Receiving files and sending them from Files come next; until then nothing shows up on the phone yet.

The driver is built for the running kernel and again after every kernel update. If a build ever fails, the kernel's own driver loads instead: AirDrop stops, the Wi-Fi keeps working. Restart after installing.

The Wi-Fi uses the computer's own hardware address on every network instead of a different one per network (Fedora's default), because AWDL's address is derived from it. Networks can then recognise the computer from one to another, as with a Mac.

Remove everything with `./install-airdrop.sh --remove` in the Nightdrive folder, then restart.

Homepage: https://github.com/netmojo-systems/omdrop-awdl
Needs: a MacBook with M1 or M2 (Broadcom Wi-Fi)
