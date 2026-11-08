---
name: local-url
description: Give a locally served web app a bookmarkable address like http://myapp.localhost:3000, with no /etc/hosts entry and no sudo on macOS, while every address that already worked (127.0.0.1, localhost, a Tailscale serve URL) keeps working. Use when the user wants a local URL, a nicer name than localhost:port, something to bookmark or favorite for a dev server or always-on local app, or invokes /local-url.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Local URL

Goal: `http://<name>.localhost:<port>` opens the app from a bookmark on this machine.
The server keeps its bind address and port; nothing that worked before stops working.

## Why `.localhost`

- RFC 6761 reserves `localhost` and every name under it for loopback. Chrome and
  Firefox answer `*.localhost` themselves, and the macOS resolver does too, so Safari,
  curl and the rest get 127.0.0.1 / ::1 with no hosts file, no sudo, no DNS.
- No public DNS name can claim it, so admitting it to a Host guard does not reopen
  DNS rebinding.
- Not `.local`: that is mDNS/Bonjour, with slow lookups and name collisions.

## Steps

1. **Find what serves the app**: port, bind address, how it runs (npm script, launchd
   or systemd unit, Docker, framework dev server). Pick the name: the app's short
   name, lowercase, e.g. `symposium.localhost`. Keep the port; dropping it means
   port 80, which only one app on the machine can have.

2. **Ask the machine before touching code:**
   ```bash
   dscacheutil -q host -a name <name>.localhost    # macOS: expect 127.0.0.1 and ::1
   getent hosts <name>.localhost                   # Linux, see below if empty
   curl -s -o /dev/null -w '%{http_code}\n' http://<name>.localhost:<port>/
   ```
   - 200: it already works; skip to step 5.
   - 400, 403, "Invalid Host header", "Blocked request": a host allow-list; step 3.
   - Connection refused: nothing listens on the address the name resolved to; see
     Pitfalls.

   Resolution: on macOS the system resolver answers `*.localhost` itself. On Linux it
   depends on the NSS setup: `nss-myhostname` (systemd) resolves it, plain
   glibc does not. If `getent` prints nothing, the "no /etc/hosts" promise
   does not hold on this machine: tell the user, and offer the one-line
   `127.0.0.1 <name>.localhost` entry (it needs sudo) rather than adding it
   yourself. Chrome and Firefox resolve `*.localhost` on their own either
   way, so a bookmark in those browsers still works without it.

3. **Admit the exact name** (not a `*.localhost` wildcard) wherever hosts are checked:
   - Custom middleware: grep for `headers.host`, `allowedHosts`, `Host header`.
   - Framework knobs: Vite `server.allowedHosts`, webpack-dev-server `allowedHosts`,
     Django `ALLOWED_HOSTS`, Rails `config.hosts`, Next.js `allowedDevOrigins`.
   - Anything keyed on origin needs `http://<name>.localhost:<port>` too: Origin
     checks on mutations, CORS allow-lists, CSRF trusted origins (Django
     `CSRF_TRUSTED_ORIGINS`), OAuth redirect URIs, cookie `Domain` attributes.
   Prefer one exported constant for the name over repeating the string.

4. **Test the guard, if the project owns it.** When step 3 changed custom
   host-checking code (middleware, an allow-list helper), add tests in the
   project's own style: the name passes, a sibling (`other.localhost:<port>`) is
   refused, and if mutations check Origin, the same pair for the origin. Then run
   the full suite and the typecheck. When step 3 only set a framework option
   (Vite `allowedHosts`, Django `ALLOWED_HOSTS`), there's no code of yours to
   test: the curl checks in step 6 cover it.

5. **Make it the address the project prints**: startup log, any `--open`, README,
   CLAUDE.md or other agent instructions, service-file comments. Mention that the old
   addresses still work.

6. **Restart and verify.** A long-running service (launchd `KeepAlive`, systemd, pm2)
   keeps the old code until restarted; check it isn't mid-request or mid-job first.
   ```bash
   for u in http://<name>.localhost:<port>/ http://127.0.0.1:<port>/ http://other.localhost:<port>/; do
     curl -s -o /dev/null -w "$u %{http_code}\n" "$u"
   done
   ```
   Expect 200, 200, and a refusal.

## Alongside Tailscale

The local name and `tailscale serve` don't interact. Serve proxies
`https://<machine>.<tailnet>.ts.net:<port>` to `http://127.0.0.1:<port>` and passes
the ts.net name as Host, so the guard keeps allowing that name as well, ideally only
when serve's `Tailscale-User-Login` header is the expected login.

- On macOS the CLI is often not on PATH:
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status` shows which
  ports are taken. The bare `https://<machine>.<tailnet>.ts.net` (443) fits one app.
- New app on the tailnet: `tailscale serve --bg --https=<port> http://127.0.0.1:<port>`.
  Never `funnel`, which makes it public.
- The tailnet URL also answers on the machine itself, so one synced bookmark can
  cover every device. The `.localhost` URL is the one that works with Tailscale off.

## Pitfalls

- **Browser storage is per origin.** localStorage, cookies, IndexedDB, service
  workers and saved logins start empty at the new address. Say so; server-side
  state is untouched.
- **IPv6 first.** The name resolves to `::1` as well as `127.0.0.1`. Browsers and
  curl fall back between them, but a strict client may not; if something fails
  where curl works, compare `curl -4` and `curl -6`.
- Don't bind `0.0.0.0` to "make it work". The name changes nothing about who can
  reach the server, and it shouldn't.

## Report

Lead with the URL to bookmark. Then what still works, what resets (browser storage),
the verification codes, and the commit if one was made.
