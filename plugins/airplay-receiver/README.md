# AirPlay Receiver

Mirror your iPhone, iPad or Mac to this computer, like macOS's AirPlay Receiver: its screen opens in a window here, and music and videos sent with AirPlay play here too. It uses UxPlay, an open-source AirPlay server.

- On the iPhone: Control Centre › Screen Mirroring › pick this computer. It shows under the computer's name (launcher › Settings › Computer name).
- The window opens along the right edge, as tall as the screen; move it anywhere. Close it with ⌘W: the receiver is ready again in a second.
- Viewing only: the phone can't be controlled with the mouse.
- The picture is up to 4K HEVC, decoded with FFmpeg: the installer adds the RPM Fusion repository for it (libavcodec-freeworld), because Fedora's own H.264 decoder smears the picture whenever it moves.

Homepage: https://github.com/FDH2/UxPlay
Needs: an iPhone, iPad or Mac on the same network
