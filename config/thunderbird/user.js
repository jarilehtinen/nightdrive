// JetBrains Mono Light/Regular (messages) + enable userChrome.css (UI font)
user_pref("font.name.sans-serif.x-western", "JetBrains Mono Light");
user_pref("font.name.serif.x-western", "JetBrains Mono Light");
user_pref("font.name.monospace.x-western", "JetBrains Mono");
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Nightdrive's decluttering (2026-10-12)
user_pref("toolbar.unifiedtoolbar.buttonstyle", 2);        // icons only in the top bar
user_pref("mail.threadpane.cardsview.rowcount", 2);        // two-line message card (subject + attachment icon on the same line)
user_pref("mail.addressDisplayFormat", 2);                 // name only in the message list, no <address>
user_pref("mail.showCondensedAddresses", true);         // name from the address book / without the address
user_pref("intl.date_time.pattern_override.date_short", "d.M.yyyy");
user_pref("intl.date_time.pattern_override.time_short", "H.mm");
user_pref("extensions.autoDisableScopes", 14);             // enable add-ons in the profile's extensions/ folder (folderpane-toggle) without asking
user_pref("svg.context-properties.content.enabled", true);  // Lucide icons (chrome/icons/lucide) follow the theme colours
