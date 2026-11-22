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
