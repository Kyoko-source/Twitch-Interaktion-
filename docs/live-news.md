# Live News

## Stream setup

Add an OBS Browser Source using `/overlays/live-news.html` on the same host as the website. Set its dimensions to **1920 x 1080** and place it above gameplay/webcam sources. The page is transparent except for the bottom 102-pixel ticker. No Twitch API connection or admin credentials are needed in OBS.

In **Admin > Live News**, enter a message, choose its type and speed, and use **Vorschau** to check it locally. **Live schalten** publishes the draft and shows the ticker. **Im Stream sichtbar** hides or restores the last publication without publishing unsaved edits. The browser source normally receives changes within about one second; during network failures it preserves the last successfully received state and retries automatically.

## API and storage

- `GET /api/live-news`: public, read-only published state; `Cache-Control: no-store`.
- `GET /api/admin/live-news`: published state, requires `X-Admin-Password`.
- `PUT /api/admin/live-news`: publish `{message, kind, speed, enabled}`, requires admin password.
- `PATCH /api/admin/live-news`: change `{enabled}` only, requires admin password.

Kinds: `breaking`, `normal`, `community`. Speed: integer 40-220 pixels/second. Messages: at most 1000 characters, whitespace normalized; an enabled ticker requires a nonempty message. Content is rendered as text, never HTML. Preview mode (`?preview=1`) accepts same-origin parent messages and never polls or writes the published state.

State is written atomically to `/data/live_news.json` in the existing persistent Docker volume. Override `LIVE_NEWS_FILE` for isolated testing. No Supabase migration is required. The store serializes writes within the current single backend process; multiple Uvicorn workers or backend replicas would require shared transactional storage or interprocess locking.

## Verification

Backend (with backend requirements installed, working directory `backend`):

```sh
python -m unittest discover -s tests -v
```

Frontend (working directory `frontend`):

```sh
npm run build
npm exec -- playwright test live-news.spec.mjs
```
