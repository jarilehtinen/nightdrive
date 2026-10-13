# Dictation (Voxtype)

Hold **F5** (or **Fn** for more than 0.3 s), speak, and let go: the text is typed into the active window. It runs fully offline
with [Voxtype](https://github.com/peteonrails/voxtype) and NVIDIA's Parakeet model, on the CPU (about 1.4 s for 6 s of speech on an M2 Max).

Voxtype isn't packaged for Fedora on aarch64, so it is installed by hand:

1. Download the aarch64 binaries from the [Voxtype releases](https://github.com/peteonrails/voxtype/releases) into `~/.local/bin`
   and check their sha256: `voxtype-onnx` (Parakeet), plus `voxtype-osd`, `voxtype-osd-quickshell` and `voxtype-audio-bridge`
   for the on-screen recording card.
2. Download the model: `voxtype-onnx setup --download --model parakeet-tdt-0.6b-v3-int8` (into `~/.local/share/voxtype/models`).
3. Install the OSD's QML: `voxtype setup quickshell --source <voxtype repo>/quickshell`. `link.sh` then replaces its
   `OsdSurface.qml` with the one in `config/voxtype/` (card at the top centre, no dimming).
4. `sudo dnf install wtype` so the text can be typed into windows (without it, it goes to the clipboard).

The settings are in `config/voxtype/config.toml`, which `link.sh` links into `~/.config/voxtype/`. Hyprland starts the
daemon at login, and `hypr/scripts/dictate` handles the keys and the muted-mic check.

Timings for 6 s of speech on the CPU: Parakeet 1.4 s, Whisper small 4.3 s, medium 13.7 s, large-v3-turbo 24 s.
