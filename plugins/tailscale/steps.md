# Setting up Tailscale by hand

Welcome to Nightdrive shows these steps one at a time when you set things up without Claude (plugins/README.md › steps.md).

Help: README.md#setting-up

## Why Tailscale

Tailscale makes a private network of your own devices: this computer, your phone, your laptop, a home server. They
find each other wherever they are, at home or on the other side of the world, and nobody else can get in.

In Nightdrive it is what lets your phone reach this computer: Ferry sends photos and files between them over it, and
Home Assistant, a NAS or another computer of yours stays a click away in the shield's menu in the top bar. It is free
for personal use.

## Log this computer in

The button opens Tailscale's login page in your browser. No account yet? The page makes one with your Google,
Microsoft, GitHub or Apple account: just pick one. Finish in the browser, then come back here: this step shows done
once the computer is connected.

Run: Open the login page | ./login
Done when: tailscale status --json | jq -e '.BackendState | IN("Running", "Stopped")'

## If the login says "Permission denied"

Only if the login page didn't open: Tailscale needs to know once that you may control it. This command asks for your
password in a terminal, then the login works. Go back a step and press the button again.

```
sudo tailscale set --operator=$USER
```

## Your phone

Install the Tailscale app on your phone (App Store or Google Play) and sign in with the same account. Your phone and
this computer now see each other.

The shield in the top bar shows whether you're connected: a right click turns Tailscale on or off, and its menu lists
your devices (a click copies a device's address).

Done when: tailscale status --json | jq -e '[.Peer[]?] | length > 0'
