# Thunderbird

`link.sh` links `config/thunderbird/userChrome.css`, `userContent.css` and `user.js` into the default profile. It also writes
`nightdrive-icons.css`, the Lucide icons with this machine's paths, and builds the unsigned **folder-pane toggle** add-on into
the profile's `extensions/`. `user.js` sets `extensions.autoDisableScopes=14`, so the add-on is enabled without asking. Its button
shows up from the second start.

Two things can't be linked and are set by hand in `xulstore.json`, with Thunderbird closed:

- Toolbar buttons: `unifiedToolbar.state` =
  `{"mail":["ext-folderpane-toggle@jokela-night","spacer","reply","reply-all","forward-inline","archive","junk","delete","spacer"]}`
- Message header: in `aboutMessage.xhtml` → `messageHeader.layout`, turn on `hideLabels`, `subjectLarge`, `showAvatar` and `showFullAddress`.

A pitfall: if you change `mail.addressDisplayFormat` in `user.js`, also bump `mail.displayname.version` in `prefs.js`. Otherwise
the cached "Name <address>" display stays as it was.
