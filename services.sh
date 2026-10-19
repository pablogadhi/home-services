#!/usr/bin/env bash
# Start or stop all home-server services (or a subset).
# Usage: ./services.sh up|down [service ...]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAST="gateway" # reverse proxy: started last, stopped first

usage() {
  echo "Usage: $0 up|down [service ...]" >&2
  echo "Services: ${ALL[*]}" >&2
  exit 1
}

compose_file() {
  local f
  for f in docker-compose.yaml docker-compose.yml compose.yaml compose.yml; do
    [[ -f "$ROOT/$1/$f" ]] && { echo "$ROOT/$1/$f"; return 0; }
  done
  return 1
}

# Discover services: every subdirectory with a compose file, gateway last.
ALL=()
for dir in "$ROOT"/*/; do
  name="$(basename "$dir")"
  [[ "$name" == "$LAST" ]] && continue
  compose_file "$name" >/dev/null && ALL+=("$name")
done
compose_file "$LAST" >/dev/null && ALL+=("$LAST")

[[ $# -ge 1 ]] || usage
cmd="$1"; shift
[[ "$cmd" == "up" || "$cmd" == "down" ]] || usage

# Selected services, kept in discovery order.
if [[ $# -eq 0 ]]; then
  selected=("${ALL[@]}")
else
  for s in "$@"; do compose_file "$s" >/dev/null || { echo "Unknown service: $s" >&2; usage; }; done
  selected=()
  for s in "${ALL[@]}"; do
    for want in "$@"; do [[ "$s" == "$want" ]] && selected+=("$s"); done
  done
fi

# Stop in reverse order.
if [[ "$cmd" == "down" ]]; then
  reversed=()
  for ((i = ${#selected[@]} - 1; i >= 0; i--)); do reversed+=("${selected[i]}"); done
  selected=("${reversed[@]}")
fi

for s in "${selected[@]}"; do
  echo "==> $cmd $s"
  args=(--project-directory "$ROOT/$s" -f "$(compose_file "$s")")
  if [[ "$cmd" == "up" ]]; then
    docker compose "${args[@]}" up -d
  else
    docker compose "${args[@]}" down
  fi
done
