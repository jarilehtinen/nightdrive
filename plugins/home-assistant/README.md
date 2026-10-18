# Home Assistant

Your smart home on the desktop: lights, switches and scenes from the launcher and the top bar, without opening Home Assistant.

- Launcher › Home: your pinned devices, then your rooms and their devices, scenes and scripts. Enter turns a device on or off or runs a scene, and the launcher stays open; ←/→ dims a light. Searching from the launcher's root finds rooms and devices too.
- Shift+Enter on a device pins it to the top bar's Home menu, where a click turns it on or off and the scroll wheel dims a light. Settings › Home picks which kinds of devices the launcher shows.
- A house in the top bar, faded while Home Assistant doesn't answer. A right click on it opens Home Assistant itself, as a web app.
- Several addresses (at home, over Tailscale, Nabu Casa): the first one that answers is used, so it works away from home too.

**Setting up**: the installer asks for your Home Assistant addresses and a long-lived access token, which you make in Home Assistant under your profile › Security (an op:// reference to 1Password works too). Run it again to change them.

Homepage: https://www.home-assistant.io
Needs: a Home Assistant server
