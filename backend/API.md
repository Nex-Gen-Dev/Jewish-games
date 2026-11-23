# Shtick Games API
| Who | Method & path | What |
|---|---|---|
| app | POST /v1/register | `{user_id,name,username,email,phone,platform,model}` → `{token}` (stored on device) |
| app | GET /v1/me/profile (Bearer token) | broadcast + this user's private patch, merged |
| admin | GET /v1/admin/users?q= | list/search users |
| admin | GET/PUT /v1/admin/users/{id}/profile | read/set one person's private patch |
| admin | PUT /v1/admin/broadcast | content for everyone |

Patch example: `{"theme":{"accent":"#ff8a3d"},"entitlements":["fighter","runner"],"message":"Shabbat shalom, Moshe!","inventory":["blaster"]}`

## Switching it on
1. `wrangler d1 create private-games`, put the id in `wrangler.toml`, `wrangler d1 execute private-games --file=schema.sql`
2. `wrangler secret put ADMIN_TOKEN`, then `wrangler deploy`
3. Add `"api_url": "https://<your-worker>.workers.dev"` to `docs/version.json`. Every installed app picks it up on its next update check, registers its account and starts receiving private updates. No new APK needed.

## Beta testers (admin)
- Beta flag lives in the user's private profile patch as `"beta": true` (the app's updater reads it to also fetch `beta.json`).
- `GET /v1/admin/users` now returns `beta` (bool) per user. `PUT /v1/admin/users/:id/beta {"beta":true|false}` flips it without touching other profile fields.
- `GET/PUT /v1/admin/settings` `{"auto_beta":bool}`: when true, every newly registered user becomes a beta tester (settings table is created lazily).
- `POST /v1/admin/notifications` accepts `"audience":"beta"` (stored with user_id `BETA`): only beta testers receive it. `GET /v1/admin/stats` returns `beta` count.
