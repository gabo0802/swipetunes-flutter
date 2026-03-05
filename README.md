# SwipeTunes (Flutter Port)

Flutter port of the original SwipeTunes project from `gabo0802/swipetunes-personal`, with an upgraded UI and modern Material 3 styling.

## Current Features

- YT Music-first login flow
- Discover tab with swipe-style interactions:
	- swipe right to like a song
	- swipe left to dismiss a song
	- play/pause preview when available
- Log tab with recently swiped songs and timestamps
- Playlist-seeded recommendation flow for YT Music
- Provider architecture kept extensible for future streaming integrations

## Run

```bash
flutter pub get
flutter run
```

## Spotify Status

Spotify support is temporarily deprecated in the current UX.

The codebase still keeps provider abstractions so Spotify (or other providers) can be re-enabled later without a full architecture rewrite.

## Google OAuth Setup (Desktop)

The YT Music button now triggers real Google OAuth on desktop using a loopback callback.

1. Copy `oauth.env.example.json` to `oauth.env.json`
2. Fill in your Google OAuth Desktop client values
3. Run:

```bash
flutter run -d windows --dart-define-from-file=secrets/oauth.env.json
```

If you see `invalid_client: Unauthorized`:

- Confirm you created a Google OAuth **Desktop app** client (not Android/iOS/Web)
- Ensure `GOOGLE_OAUTH_CLIENT_ID` exactly matches that desktop client ID
- Use `GOOGLE_OAUTH_CLIENT_TYPE=desktop`
- Set `GOOGLE_OAUTH_CLIENT_SECRET` to the value from your Desktop OAuth JSON (some desktop clients require it during token exchange)

## Notes

- This port keeps the original product flow: `Login -> Discover -> Log`.
- YT Music is the active provider path right now.
- Playlist export is intentionally disabled while provider integrations are being refreshed.
