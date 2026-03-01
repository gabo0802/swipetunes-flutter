# SwipeTunes (Flutter Port)

Flutter port of the original SwipeTunes project from `gabo0802/swipetunes-personal`, with an upgraded UI and modern Material 3 styling.

## Current Features

- Spotify-inspired login screen
- Discover tab with swipe-style interactions:
	- swipe right to like a song
	- swipe left to dismiss a song
	- play/pause preview when available
- Log tab with recently swiped songs and timestamps
- Export liked songs to a Spotify playlist (when token is configured)
- Demo mode fallback when no Spotify token is provided

## Run

```bash
flutter pub get
flutter run
```

## Spotify Setup (Optional)

The app supports direct Spotify API calls using a pre-generated OAuth access token.

Run with:

```bash
flutter run --dart-define=SPOTIFY_ACCESS_TOKEN=your_access_token_here
```

If no token is provided, SwipeTunes runs in demo mode using local sample tracks.

## Google OAuth Setup (Desktop)

The YT Music button now triggers real Google OAuth on desktop using a loopback callback.

1. Copy `oauth.env.example.json` to `oauth.env.json`
2. Fill in your Google OAuth Desktop client values
3. Run:

```bash
flutter run -d windows --dart-define-from-file=secrets/oauth.env.json
```

You can combine both configs in the same file by adding `SPOTIFY_ACCESS_TOKEN` too.

If you see `invalid_client: Unauthorized`:

- Confirm you created a Google OAuth **Desktop app** client (not Android/iOS/Web)
- Ensure `GOOGLE_OAUTH_CLIENT_ID` exactly matches that desktop client ID
- Use `GOOGLE_OAUTH_CLIENT_TYPE=desktop`
- Set `GOOGLE_OAUTH_CLIENT_SECRET` to the value from your Desktop OAuth JSON (some desktop clients require it during token exchange)

## Notes

- This port keeps the original product flow: `Login -> Discover -> Log`.
- Spotify playlist creation still requires a valid Spotify access token.
- YT Music recommendations and export are currently scaffolded and still use demo recommendation data after Google sign-in.
