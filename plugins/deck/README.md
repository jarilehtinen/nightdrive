# Deck

A fast Spotify player, made for Nightdrive: your albums in the launcher, the player in the top bar, and a window only when you want one.

- Launcher › Music: your albums, the Curated list and Spotify search (artists, albums and songs). Typing there finds your shelf's and Curated's artists and albums, with a row that searches Spotify for the same words. Enter plays: a song plays its album from that song.
- The launcher's own search leaves Deck out unless you turn on Settings › Launcher › Include Deck artists, albums and songs: then your shelf's and Curated's albums and artists come up among the hits, with a row that searches Spotify for what you typed (Spotify is asked only when you pick it).
- While music plays, a player row sits on top of the launcher, and Ctrl+Space plays or pauses.
- The music icon in the top bar opens the player: the cover, the controls, the like and the speaker to play on.
- Hyper+M (Caps Lock + M) opens Deck's window: your shelf, Curated, Spotify search and the queue, with the player along the bottom. ⌘W closes it, and the music keeps playing.

## The window

The sidebar's sections are Shelf, Curated, Search and Queue (⌘1–4 or Ctrl+↑ ↓, / searches). Enter opens an artist or an album and plays a song; Esc or ⌫ goes back. On a row, p plays the album (or the song), e queues the album or the song, a puts the album on your shelf or takes it off, and d removes a track from the queue. Space plays and pauses, ← → skip a track and l likes the playing one. `?` or Ctrl+? shows all the keys.

A click opens an artist or an album, a double click plays a song. An album's own buttons play, queue and shelve it, and the player's shelf icon, by the album's name, does the same for the album that plays. Curated shows each album's cover, and its New list button has Claude Code make a new list (`deck curate`, a few minutes on your Claude plan): the first press says so, the second starts it, and the list changes when it is ready, even if you close the window meanwhile. The covers' addresses are kept in `~/.cache/deck/covers.json`; the images come from Spotify each time.

The music plays in `deck serve`, Deck without its screen, which the window starts when no Deck runs; the window only talks to it. `deck` in a terminal still gives you Deck's own screen when no other Deck is running. `deck-open quit` closes the window and stops the music, `deck-open restart` and `deck-open log` are for trying out changes to the window (`app/`).

## Setting up

The installer builds Deck from source (a few minutes), and `nightdrive update` builds it again when it changes. Deck needs the Client ID of your own free Spotify developer app: Deck's README shows how.

Homepage: https://github.com/nightdrive-sh/deck
Needs: Spotify Premium
Keys: Hyper+M
