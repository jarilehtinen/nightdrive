# AirPlay Receiver

Mirror your iPhone, iPad or Mac to this computer, like macOS's AirPlay Receiver. On the iPhone: Control Centre › Screen Mirroring › pick this computer. Its screen opens in a window along the right edge; move it anywhere. Music and videos sent with AirPlay play here too.

It uses UxPlay, an open-source AirPlay server. The picture is 4K HEVC, decoded with FFmpeg: the installer adds the RPM Fusion repository for it (libavcodec-freeworld), because Fedora's own H.264 decoder smears the picture whenever it moves.

Viewing only: the phone can't be controlled with the mouse. Close the window with ⌘W; the receiver is ready again in a second. Turn it off with `~/.config/hypr/scripts/airplay-receiver disable`.

Homepage: https://github.com/FDH2/UxPlay
Needs: an iPhone, iPad or Mac on the same network
