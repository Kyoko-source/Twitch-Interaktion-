# Live News

## Stream setup

Add an OBS Browser Source using `/overlays/live-news.html` on the same host as the website. Set its dimensions to **1920 x 1080** and place it above gameplay/webcam sources. The page is transparent except for the bottom 102-pixel ticker. No Twitch API connection or admin credentials are needed in OBS.

In **Admin > Live News**, enter a message and choose its type, speed and playback limit: **Durchlaeufe** (1-20 complete right-to-left passes) or **Zeitdauer** (5-3600 seconds). The default is three passes. **Vorschau** checks the draft locally; **Live schalten** starts a new publication, including when the text is unchanged. **Im Stream sichtbar** hides or restarts the last publication without publishing unsaved edits. The browser source normally receives changes within about one second. It keeps its existing deadline during network failures and never restarts an expired publication after reloading.

Each type has an original PCM sound: dramatic broadcast sting for breaking news, a clean chime for normal news, and an upbeat arcade-style flourish for community news. **Sound beim Start** and **Lautstaerke** control published audio; **Sound testen** auditions it locally without publishing anything. Sounds play once per publication, not once per text pass. Hiding or replacing a message stops its audio. Session storage prevents replaying the same sound on a quick browser refresh; publications older than five seconds never trigger a late sound.

For separate stream-audio mixing, enable **Audio ueber OBS steuern** (**Control audio via OBS**) in the Browser Source properties and unmute that source in the OBS mixer. OBS itself allows browser-source autoplay ([OBS browser implementation](https://github.com/obsproject/obs-browser/blob/master/browser-app.cpp)); a normal browser may require interaction first. After updating an existing source, refresh its cached page once. The source URL and 1920 x 1080 dimensions are unchanged.

## API and storage

- `GET /api/live-news`: public, read-only published state; `Cache-Control: no-store`.
- `GET /api/admin/live-news`: published state, requires `X-Admin-Password`.
- `PUT /api/admin/live-news`: publish settings, requires admin password.
- `PATCH /api/admin/live-news`: change `{enabled}` only, requires admin password.

Settings: `message`, `kind` (`breaking`, `normal`, `community`), `speed` (integer 40-220 pixels/second), `enabled`, `playback_mode` (`loops` or `duration`), `repeat_count` (integer 1-20), `duration_seconds` (integer 5-3600), `cycle_seconds` (finite number 1-1800), `sound_enabled` and `volume` (integer 0-100). Messages are at most 1000 characters, whitespace normalized; an enabled ticker requires a nonempty message. The admin measures `cycle_seconds` using the actual fonts in its full-resolution preview before publishing. All clients use this shared cycle duration, giving consistent count limits regardless of when they connect. For nominal pixel speed, keep the OBS source width at 1920.

Published state includes `revision`, `updated_at` and `ends_at`. The backend derives `enabled=false` once the deadline passes, without requiring a connected browser or background job. Re-enabling preserves all settings and starts a new deadline/revision. Old stored publications receive finite defaults and expire relative to their original timestamp. Content is rendered as text, never HTML. Preview mode (`?preview=1`) accepts same-origin parent messages and never polls or writes the published state; preview animation is silent, with a separate explicit sound audition.

State is written atomically to `/data/live_news.json` in the existing persistent Docker volume. Override `LIVE_NEWS_FILE` for isolated testing. No Supabase migration is required. The store serializes writes within the current single backend process; multiple Uvicorn workers or backend replicas would require shared transactional storage or interprocess locking.

## Verification

Browser plugin not available; use the existing Playwright/Microsoft Edge workflow. Cover desktop (1440 x 1000), mobile (390 x 844) and the full-resolution overlay (1920 x 1080). Tests exercise actual WAV decoding/playback with the same autoplay policy used by OBS, deadline expiry with a disconnected network, finite CSS passes, duplicate publication/reload behavior, preview isolation, audio stop/mute/volume, and validation/persistence. Stream mixing in an external OBS/Twitch session still needs verification on the streaming machine.

Regenerate the original sound files with `node tools/generate-live-news-sounds.mjs` from the repository root.

Backend (with backend requirements installed, working directory `backend`):

```sh
python -m unittest discover -s tests -v
```

Frontend (working directory `frontend`):

```sh
npm run build
npm exec -- playwright test live-news.spec.mjs
```
