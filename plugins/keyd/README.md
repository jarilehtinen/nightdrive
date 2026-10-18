# Mac Keyboard Shortcuts

The text keys your fingers know from macOS, everywhere on the desktop, and Finder's keys in Files.

- ⌥⌫ deletes the word before the cursor.
- ⌘⌫ deletes to the start of the line. In Files it moves the selection to the trash, in Thunderbird it deletes the message.
- In Files, as in Finder: Enter renames the selected file and ⌘O opens it. F2 still renames too, and in the location bar, the search field and the rename box Enter works as before.

keyd turns the text keys into real key presses before they reach the desktop, so they work the same in every app and a key never gets stuck repeating. ⌘⌫ follows the app from the next login; the Files keys take effect the next time Files starts.

If the keyboard ever stops working, pressing Backspace, Escape and Enter together stops keyd. Turn it off with `sudo systemctl disable --now keyd`. `nightdrive plugins off keyd` leaves keyd running: only the Files keys and ⌘⌫ per app stop (from the next login).

Homepage: https://github.com/rvaiya/keyd
Keys: ⌥⌫, ⌘⌫, and Enter and ⌘O in Files
