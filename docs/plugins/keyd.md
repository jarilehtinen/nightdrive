# Mac Keyboard Shortcuts

The keys your fingers know from macOS:

- ⌥⌫ deletes the word before the cursor.
- ⌘⌫ deletes to the start of the line. In Files it moves the selection to the trash, in Thunderbird it deletes the message.
- In Files, like in Finder: Enter renames the selected file and ⌘O opens it. F2 still renames too. In the location bar, the search field and the rename box Enter works as before.

The text keys are turned into real key presses by keyd before they reach the desktop, so they work the same everywhere and a key never gets stuck repeating. The Files keys come from a small Nautilus extension; they take effect the next time Files starts.

If the keyboard ever stops working, pressing Backspace, Escape and Enter together stops keyd. Off again: `sudo systemctl disable --now keyd`.

Homepage: https://github.com/rvaiya/keyd
