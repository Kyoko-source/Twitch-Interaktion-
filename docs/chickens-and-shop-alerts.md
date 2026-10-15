# Chickens and shop alerts

Chickens are the only spendable currency. Old Pepple/braincell balances are not converted or exposed by the API. Game titles such as PEPPLE Pinball remain game names. `chickens_earned` is the lifetime statistic for earned Chickens, not another wallet. Levels and the community ranking use this statistic; spending Chickens never lowers a level.

## OBS

Add a Browser Source using **http://62.238.49.219/overlays/shop-alert.html**, at **1920 × 1080**, above the game capture. The screen stays transparent except for the centered notification. The existing Live News browser source is separate and can remain enabled.

In **Admin → Shop-Alerts**, copy the source URL, preview an example privately, and set the display duration (5–20 seconds; default 10). Preview does not publish a fake purchase. Each successful purchase in `Bestrafungs Ideen` or legacy `Idee Bestrafungsrad` atomically schedules one notification with the buyer, item name and paid price. Other categories produce no punishment alert. Simultaneous purchases queue with a one-second gap. An unavailable OBS source does not block checkout: scheduled messages expire instead of replaying historical purchases on a later stream. Reloading a source cannot replay a message already shown in that browser session.

The overlay uses text nodes, not HTML, for names and catalog text. Deadlines use server time and a monotonic browser clock. A currently visible notification expires even if the network fails. Initial updates poll once per second. No credentials belong in the source URL.

## Game economy

Start an authenticated round, play, then submit the score at the end. Snake also has **Runde abschließen**. A round must run at least 15 seconds and reach a game's score threshold before it can pay anything.

| Rule | Value |
| --- | --- |
| Maximum per round | 25 Chickens |
| Maximum per account per UTC day | 120 Chickens |
| Play-time bound | At most 1 Chicken per 10 elapsed seconds |
| Jump score requirement | 100 points per Chicken |
| Snake score requirement | 10 points per Chicken |
| Pinball score requirement | 2,500 points per Chicken |
| Survivor score requirement | 200 points per Chicken |
| Level interval | 250 lifetime earned Chickens |

The actual reward is the minimum of the score allowance, play-time allowance, round limit and remaining daily allowance. An account has one active earning round across all tabs/games. Server-issued run IDs expire after two hours, bind the account and game, and can only be credited once. Duplicate purchase request IDs can only debit once. Concurrent purchases cannot overspend. Client-rendered games still report their own scores; these checks limit rewards and replay, but are not authoritative server-side physics or complete cheat prevention.

The old daily-login currency bonus is retired. Admin adjustments are logged wallet corrections and do not inflate the earned leaderboard. Wallet updates appear immediately after checkout or score submission in the current browser.

## Catalog rebalance

The one-time migration triples punishment prices with a minimum of 150 Chickens. Existing tasks are tripled with a minimum of 250. Other catalog categories retain their prices. Current punishment prices become: water 150; no sprinting, low DPI and high DPI 300 each; 3 Squats 450; 1 push-up 600. Built-in chat animations cost 300 / 450 / 600 / 900 Chickens. Existing animation ownership is retained.

## Persistence, reset and deployment

Identity/catalog/history remain in Supabase. New wallets, earning rounds, score submissions, purchases, admin adjustments and the notification outbox share transactions in **`/data/economy.sqlite3`**, in the existing `backend_data` Docker volume. This is the currency source of truth; legacy Supabase balances are retired projections and must not be used to credit new funds. Include this volume in backups. SQLite transactions work across workers on the same filesystem; backend replicas on separate machines require moving the ledger to a shared transactional database first.

The reset is explicit, not a startup side effect:

```sh
# With the previous backend stopped and the updated backend image built:
docker compose -f deploy/docker-compose.web.yml --env-file deploy/.env run --rm --no-deps backend python -m app.migrate_chickens --apply
docker compose -f deploy/docker-compose.web.yml --env-file deploy/.env up -d backend frontend
```

The migration saves old user balances and original catalog prices to **`/data/backups/chickens-v1.json`**, resets legacy Chickens to zero, applies prices from the original snapshot, and then marks the new ledger ready. If a step fails, checkout/earning remain disabled. Retrying uses the original prices, so it cannot triple twice. Once initialized, rerunning does nothing and restarting a container never resets earned Chickens. To inspect counts without applying changes, omit `--apply`. The reset backup excludes passwords and credentials.

API: `GET /api/economy`, authenticated `POST /api/game-runs`, authenticated `POST /api/scores` with `run_id`, authenticated `POST /api/shop/purchase` with `request_id`, public read-only `GET /api/purchase-alerts`, and admin-protected `GET/PUT /api/admin/purchase-alerts`. A legacy score-only client needs to refresh to receive the new round flow.

Verification: backend unit/API tests cover caps, duplicate submissions, atomic failed purchases, simultaneous debits, queuing, restart persistence and one-time reset; `frontend/tests/shop-economy.spec.mjs` covers wallet updates, round registration, checkout, responsive shop, admin preview and OBS playback. The design uses code-native SVG and CSS, based on an Image Gen preview of a centered charcoal/violet reward card with crown, gift, buyer, item, Chicken price and countdown.
