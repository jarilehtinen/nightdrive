# Setting up Deck by hand

Welcome to Nightdrive shows these steps one at a time when you set things up without Claude (plugins/README.md › steps.md).
Deck's own README has the details: a source build's, the package's, then this folder's page.

Help: ~/.local/src/deck/README.md#2-create-your-own-spotify-app
Help: /usr/share/doc/deck/README.md#2-create-your-own-spotify-app
Help: README.md#setting-up

## Why Deck

Deck is Nightdrive's own Spotify player, made to stay out of your way: your albums are in the launcher, the player is
in the top bar, and Hyper+M (Caps Lock + M) opens its window only when you want one. It plays your Spotify, so it needs
Spotify Premium.

Spotify lets a player like Deck search and like songs only through an "app" of your own on Spotify's developer site.
It is free and takes a couple of minutes: the next steps make it.

## Make your own Spotify app

The button opens Spotify's developer dashboard. Log in with the Spotify account you play music with, accept the
developer terms if asked, then:

1. Click **Create app**. Name and description can be anything, "Deck" for one.
2. In **Redirect URIs**, type exactly `http://127.0.0.1:8898/login` and click **Add**.
3. Under the APIs, check **Web API**, accept the terms and click **Save**.
4. Open the app's **Settings**: you'll need its **Client ID** in the next step (not the secret).

Open: Spotify's developer dashboard | https://developer.spotify.com/dashboard

## Give Deck the Client ID

Copy the Client ID from the app's settings and paste it here. The command then adds it to Deck's settings file.

Ask: client_id | The Client ID | 1a2b3c…

```
mkdir -p ~/.config/deck && echo 'client_id = "{client_id}"' >> ~/.config/deck/config.toml
```

Done when: grep -qE '^\s*client_id\s*=\s*"[^"]+"' ~/.config/deck/config.toml

## Sign the player in

The player restarts with your app: your browser opens "Sign in to the Deck Spotify app", and you accept it there. That
is the only sign-in, and it happens in your browser: Deck never sees your password.

Run: Restart the player | deck ctl quit; deck-window player

## Curated, for when you have Claude

Curated is a list of albums picked for you each week, with a reason for each. Claude makes it, so it needs Claude Pro
or Max; the rest of Deck works without.

To have it ready, write a few lines about the music you like: artists and albums you love, eras, moods, what you want
more of. The button opens the file in the text editor. Putting favourite albums on Deck's shelf helps too (search,
then a). Or skip this step: s in the list puts Deck aside, and you can come back later.

Help: ~/.local/src/deck/README.md#setting-up-curated-optional-recommended
Help: /usr/share/doc/deck/README.md#setting-up-curated-optional-recommended
Edit: ~/.config/deck/taste.md
Done when: grep -q '[^[:space:]]' ~/.config/deck/taste.md
