# Home server services

Docker Compose stacks for the home server, one directory per stack.

```bash
./services.sh up              # start everything
./services.sh down            # stop everything
./services.sh up media gateway   # start only some stacks
```

| Stack | Containers | Purpose | Ports |
|---|---|---|---|
| `gateway` | nginx | Reverse proxy for `*.commander.one` (see [gateway/README.md](gateway/README.md)) | 80 (host) |
| `filegator` | filegator | Web file manager for `/mnt/media` | 8080 |
| `gamesaves` | syncthing, restic-backup, restic-prune | Game save sync, with daily backups and weekly prunes to `/mnt/media/backup/gamesaves` | 8384 (host) |
| `homeassistant` | homeassistant, whisper, piper, microwakeword, ewelink | Home automation, voice (STT/TTS/wake word), eWeLink devices | 8123 (host), 10300, 10200, 10400 |
| `media` | jellyfin, sonarr, radarr, prowlarr, bazarr, flaresolverr | Media server and automation | 8096, 8989, 7878, 9696, 6767, 8191 |
| `qbittorrent` | gluetun, qbittorrent | Torrent client behind a ProtonVPN WireGuard tunnel | 8081 |

## Notes

- Runtime data, app config and secrets are git-ignored. Bulk data lives in `/mnt/media`.
- Secrets to create: `qbittorrent/.env` (`WG_PRIVATE_KEY=...`), `homeassistant/.ewelink_env`, `gamesaves/restic_password`.
- The `ewelink_smart_home` image is built locally from `homeassistant/ewelink-ha-addon`.
