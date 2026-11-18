import { ADMIN_HTML } from "./admin_html.js";
// Private Games API (Cloudflare Worker + D1).
const json = (o, status = 200) => new Response(JSON.stringify(o), {
  status, headers: { "content-type": "application/json", "access-control-allow-origin": "*",
    "access-control-allow-headers": "authorization,content-type", "access-control-allow-methods": "GET,POST,PUT,OPTIONS" } });
const sha = async (s) => [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)))]
  .map(b => b.toString(16).padStart(2, "0")).join("");
const merge = (a, b) => { const o = { ...a }; for (const k in b) o[k] = (o[k] && b[k] && typeof o[k] === "object" && typeof b[k] === "object" && !Array.isArray(b[k])) ? merge(o[k], b[k]) : b[k]; return o; };
const bearer = (r) => (r.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");

export default {
  async fetch(req, env) {
    const url = new URL(req.url); const p = url.pathname;
    if (req.method === "OPTIONS") return json({});
    try {
      if (p === "/admin") return new Response(ADMIN_HTML, { headers: { "content-type": "text/html; charset=utf-8" } });
      if (p === "/" || p === "/health") {
        let db = "missing binding (DB)";
        if (env.DB) { try { await env.DB.prepare("SELECT 1").first(); db = "ok"; } catch (e) { db = "error: " + e; } }
        return json({ ok: true, service: "private-games-api", database: db, admin_token_set: !!env.ADMIN_TOKEN });
      }
      // ---- app: register (idempotent per user_id)
      if (p === "/v1/register" && req.method === "POST") {
        const b = await req.json();
        if (!/^PG-[A-Z0-9]{8}$/.test(b.user_id || "") || !b.name || !/^[a-z0-9_.]{3,20}$/.test(b.username || "")) return json({ error: "bad input" }, 400);
        const existing = await env.DB.prepare("SELECT user_id FROM users WHERE user_id=?").bind(b.user_id).first();
        if (existing) return json({ error: "already registered" }, 409);
        const token = crypto.randomUUID() + crypto.randomUUID();
        try {
          await env.DB.prepare("INSERT INTO users (user_id,name,username,email,phone,token_hash,platform,model,created_at) VALUES (?,?,?,?,?,?,?,?,?)")
            .bind(b.user_id, b.name, b.username, b.email || null, b.phone || null, await sha(token), b.platform || null, b.model || null, Date.now()).run();
        } catch (e) { return json({ error: "username taken" }, 409); }
        return json({ ok: true, token }, 201);
      }
      // ---- app: my private profile = broadcast + my patch
      if (p === "/v1/me/profile" && req.method === "GET") {
        const u = await env.DB.prepare("SELECT user_id, disabled FROM users WHERE token_hash=?").bind(await sha(bearer(req))).first();
        if (!u || u.disabled) return json({ error: "unauthorized" }, 401);
        await env.DB.prepare("UPDATE users SET last_seen=? WHERE user_id=?").bind(Date.now(), u.user_id).run();
        const bc = await env.DB.prepare("SELECT patch FROM broadcast WHERE id=1").first();
        const mine = await env.DB.prepare("SELECT patch FROM user_profile WHERE user_id=?").bind(u.user_id).first();
        return json(merge(JSON.parse(bc?.patch || "{}"), JSON.parse(mine?.patch || "{}")));
      }
      // ---- admin
      if (p.startsWith("/v1/admin/")) {
        if (!env.ADMIN_TOKEN || bearer(req) !== env.ADMIN_TOKEN) return json({ error: "unauthorized" }, 401);
        if (p === "/v1/admin/users" && req.method === "GET") {
          const q = url.searchParams.get("q"); const like = `%${q || ""}%`;
          const r = await env.DB.prepare("SELECT user_id,name,username,email,phone,platform,model,created_at,last_seen,disabled FROM users WHERE name LIKE ?1 OR username LIKE ?1 OR email LIKE ?1 OR phone LIKE ?1 OR user_id LIKE ?1 ORDER BY created_at DESC LIMIT 200").bind(like).all();
          return json(r.results);
        }
        let m;
        if ((m = p.match(/^\/v1\/admin\/users\/(PG-[A-Z0-9]{8})\/profile$/))) {
          if (req.method === "GET") { const r = await env.DB.prepare("SELECT patch FROM user_profile WHERE user_id=?").bind(m[1]).first(); return json(JSON.parse(r?.patch || "{}")); }
          if (req.method === "PUT") {
            const patch = JSON.stringify(await req.json());
            await env.DB.prepare("INSERT INTO user_profile (user_id,patch,updated) VALUES (?1,?2,?3) ON CONFLICT(user_id) DO UPDATE SET patch=?2, updated=?3").bind(m[1], patch, Date.now()).run();
            return json({ ok: true });
          }
        }
        if (p === "/v1/admin/stats" && req.method === "GET") {
          const now = Date.now();
          const t = await env.DB.prepare("SELECT COUNT(*) total, SUM(created_at>?1) new24h, SUM(last_seen>?2) active7d, SUM(disabled) disabled FROM users").bind(now - 864e5, now - 6048e5).first();
          const pl = await env.DB.prepare("SELECT COALESCE(platform,'unknown') k, COUNT(*) v FROM users GROUP BY 1").all();
          const rc = await env.DB.prepare("SELECT name,username,created_at FROM users ORDER BY created_at DESC LIMIT 6").all();
          return json({ total: t.total || 0, new24h: t.new24h || 0, active7d: t.active7d || 0, disabled: t.disabled || 0,
            platforms: Object.fromEntries(pl.results.map(r => [r.k, r.v])), recent: rc.results });
        }
        if ((m = p.match(/^\/v1\/admin\/users\/(PG-[A-Z0-9]{8})\/status$/)) && req.method === "PUT") {
          const b = await req.json();
          await env.DB.prepare("UPDATE users SET disabled=? WHERE user_id=?").bind(b.disabled ? 1 : 0, m[1]).run();
          return json({ ok: true });
        }
        if (p === "/v1/admin/broadcast" && req.method === "GET") {
          const r = await env.DB.prepare("SELECT patch FROM broadcast WHERE id=1").first();
          return json(JSON.parse(r?.patch || "{}"));
        }
        if (p === "/v1/admin/broadcast" && req.method === "PUT") {
          await env.DB.prepare("UPDATE broadcast SET patch=? WHERE id=1").bind(JSON.stringify(await req.json())).run();
          return json({ ok: true });
        }
      }
      return json({ error: "not found" }, 404);
    } catch (e) { return json({ error: String(e) }, 500); }
  },
};
