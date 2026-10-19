# commander.one gateway

Nginx reverse proxy in Docker Compose, routing `http://<service>.commander.one/`
to services running on the host. Every service gets its own subdomain vhost
and is served at the root of that vhost, so login redirects, absolute asset
paths and session cookies all behave exactly as they would without a proxy.

## Layout

```
gateway/
├── docker-compose.yml
└── nginx/
    ├── conf.d/gateway.conf        # routing rules
    ├── snippets/proxy_common.conf # shared proxy headers
    ├── html/index.html            # landing page at /
    └── logs/                      # created on first run
```

## Start

```bash
docker compose up -d
docker compose exec gateway nginx -t     # validate config
docker compose exec gateway nginx -s reload   # apply changes without restart
```

The gateway container uses `network_mode: host`, so it binds host port 80
directly and reaches backends over `127.0.0.1:<port>`. A commented-out
bridge-networking alternative is in `docker-compose.yml`; switching to it
means changing every `127.0.0.1` in `gateway.conf` to `host.docker.internal`.

## Per-service setup

Since routing is subdomain-based, every app is served at `/` and needs its
base-path/URL-base setting **cleared** (not set to a prefix) if it was ever
configured for one. One-time change, then a restart.

| Service | Vhost | Where to clear the base URL |
|---|---|---|
| FileGator | `filegator.commander.one` | `configuration.php` → `'APP_URL' => '/'` |
| eWeLink | `ewelink.commander.one` | app-specific base-path/`PUBLIC_URL` env var |
| Jellyfin | `jellyfin.commander.one` | Dashboard → Networking → Base URL |
| Sonarr | `sonarr.commander.one` | Settings → General → Host → URL Base |
| Radarr | `radarr.commander.one` | Settings → General → Host → URL Base |
| Bazarr | `bazarr.commander.one` | Settings → General → Base URL |
| Home Assistant | `homeassistant.commander.one` / `ha.commander.one` | n/a — no base-path option |
| AdGuard Home | `adguardhome.commander.one` / `adguard.commander.one` | n/a — no base-path option |
| qBittorrent | `qbittorrent.commander.one` / `qbt.commander.one` | Web UI → clear "Web UI Base URL" |
| Prowlarr | `prowlarr.commander.one` | Settings → General → Host → URL Base |
| Syncthing | `syncthing.commander.one` | n/a — no base-path option, but requires a Host-check exemption (see below) |
| Job Scout | `job-scout.commander.one` | n/a — set `JOB_SCOUT_FEEDBACK__BASE_URL=http://job-scout.commander.one` in `~/job-scout/.env` |

### Home Assistant

HA has no base-path option and hardcodes `/api/`, `/auth/`,
`/frontend_latest/` at the root, so it was always going to need a subdomain
vhost. Add this to `configuration.yaml` or HA will reject the proxied
requests:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
```

Restart HA afterwards.

### AdGuard Home

Same limitation — the admin UI assumes it's mounted at `/`. Served at
`adguardhome.commander.one` / `adguard.commander.one`.

### qBittorrent

Settings → Web UI: clear "Web UI Base URL" and untick "Enable Host header
validation", then restart. Without that untick every request 401s, because
qBittorrent compares the Host header against its own bind address.

## DNS

Add these to your local DNS server alongside `commander.one`:

```
filegator.commander.one       → <server IP>
homeassistant.commander.one   → <server IP>
ha.commander.one              → <server IP>
ewelink.commander.one         → <server IP>
jellyfin.commander.one        → <server IP>
sonarr.commander.one          → <server IP>
radarr.commander.one          → <server IP>
bazarr.commander.one          → <server IP>
adguardhome.commander.one     → <server IP>
adguard.commander.one         → <server IP>
qbittorrent.commander.one     → <server IP>
qbt.commander.one             → <server IP>
prowlarr.commander.one        → <server IP>
syncthing.commander.one       → <server IP>
job-scout.commander.one       → <server IP>
```

A wildcard `*.commander.one` record is simpler and covers future services.

## HTTPS

Left as plain HTTP since everything is LAN-internal. If you want TLS,
`commander.one` is a real TLD so a public CA is possible via DNS-01 (Let's
Encrypt + your registrar's API) — HTTP-01 won't work because the host isn't
reachable from the internet. Otherwise a self-signed cert or a small internal
CA trusted on your devices works fine.

## If services move to a shared Docker network

Cleaner long-term than host networking: put the containerised services and the
gateway on one user-defined bridge network and proxy to container names
(`http://jellyfin:8096`). Only the systemd services would still need
`host.docker.internal`. That also lets you stop publishing each service's port
on the host, so the gateway becomes the only way in.

## Troubleshooting

- **502 Bad Gateway** — backend down, or bound to a specific interface rather
  than `0.0.0.0`/`127.0.0.1`. Check with `ss -tlnp | grep <port>`.
- **Blank page / 404s on assets** — the app's base URL isn't cleared. Open dev
  tools and look at where the failing requests point.
- **Login loops** — usually a missing `X-Forwarded-Proto` or an untrusted
  proxy on the app side.
- **Live updates not working** — websocket upgrade; confirm the `map` block at
  the top of `gateway.conf` is present.
