# Mac text keys

The text editing keys your fingers know from macOS, in every app:

- ⌥⌫ deletes the word before the cursor.
- ⌘⌫ deletes to the start of the line. In Files it moves the selection to the trash, in Thunderbird it deletes the message.

The keys are turned into real key presses by keyd before they reach the desktop, so they work the same everywhere and a key never gets stuck repeating.

If the keyboard ever stops working, pressing Backspace, Escape and Enter together stops keyd. Off again: `sudo systemctl disable --now keyd`.

Homepage: https://github.com/rvaiya/keyd
