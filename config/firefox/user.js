// Allows the profile's chrome/userChrome.css (needed to move the tabs below the address bar)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Spell checking off (in every text field)
user_pref("layout.spellcheckDefault", 0);
// Dark UI (Jokela Night)
user_pref("browser.theme.toolbar-theme", 0);
user_pref("browser.theme.content-theme", 0);
// Scroll speed (default 100). The touchpad speed is set in hypr/scroll.lua with every other app's. Needs a Firefox restart.
user_pref("mousewheel.default.delta_multiplier_y", 100);   // the default, set explicitly so an older value in prefs.js is reset
// Touchpad momentum like macOS: a fling glides a little longer (friction, default 0.002), and quick repeated flings
// in the same direction speed up (multipliers, default 1.0)
user_pref("apz.fling_friction", "0.0015");
user_pref("apz.fling_accel_base_mult", "1.3");
user_pref("apz.fling_accel_supplemental_mult", "1.2");
// Developer mode: Browser Toolbox (Ctrl+Shift+Alt+I) for inspecting the UI's CSS
user_pref("devtools.chrome.enabled", true);
user_pref("devtools.debugger.remote-enabled", true);
user_pref("devtools.debugger.prompt-connection", false);
// Default background of a blank page (about:blank) in dark mode: Jokela Night violet (default #1c1b22)
user_pref("browser.display.background_color.dark", "#1f2033");
