#!/bin/sh
set -eu

MARGIN_GB="10"
QB_URL="http://localhost:9500"
QB_USER=""
QB_PASS=""
DISCORD_WEBHOOK=""

LOG_FILE="/media/scripts/qb_guard.log"
DRY_RUN="${DRY_RUN:-0}"

TORRENT_NAME="${1:-}"
TORRENT_SIZE="${2:-0}"
SAVE_PATH="${3:-/media/descargas}"
INFO_HASH="${4:-}"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*" >> "$LOG_FILE"; }
to_bytes_from_gb() { awk 'BEGIN{printf "%d", '"$1"'*1024*1024*1024}'; }
b2gb() { awk 'BEGIN{printf "%.2f", '"$1"'/1024/1024/1024}'; }

json_escape_oneline() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

discord_send() {
  [ -z "$DISCORD_WEBHOOK" ] && { log "DISCORD: webhook empty, skipping"; return; }

  title_raw="Torrent removed: not enough space"
  name_esc=$(printf '%s' "$TORRENT_NAME" | json_escape_oneline)
  path_esc=$(printf '%s' "$SAVE_PATH"    | json_escape_oneline)
  hash_esc=$(printf '%s' "$INFO_HASH"    | json_escape_oneline)
  size_gb=$(b2gb "$TORRENT_SIZE")
  free_gb=$(b2gb "$FREE_BYTES")
  margin_gb="$MARGIN_GB"
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  title_esc=$(printf '%s' "$title_raw" | json_escape_oneline)
  json_embed=$(printf \
'{"embeds":[{"title":"%s","color":16711680,"timestamp":"%s","fields":[{"name":"Name","value":"%s"},{"name":"Size","value":"%s GB","inline":true},{"name":"Free","value":"%s GB","inline":true},{"name":"Margin","value":"%s GB","inline":true},{"name":"Path","value":"%s"},{"name":"Hash","value":"%s"}]}]}' \
    "$title_esc" "$timestamp" "$name_esc" "$size_gb" "$free_gb" "$margin_gb" "$path_esc" "$hash_esc")

  HTTP=$(curl -sS -w "%{http_code}" -o /tmp/discord.out \
    -H "Content-Type: application/json" -d "$json_embed" \
    "$DISCORD_WEBHOOK" 2>/tmp/discord.err || echo "000")
  log "DISCORD HTTP(embed)=$HTTP"
  [ -s /tmp/discord.err ] && log "DISCORD ERR(embed)=$(cat /tmp/discord.err)"
  [ -s /tmp/discord.out ] && log "DISCORD OUT(embed)=$(cat /tmp/discord.out)"

  if [ "$HTTP" != "204" ]; then
    content_line=$(printf 'Removed (no space) | Name: %s | Size: %s GB | Free: %s GB | Margin: %s GB | Path: %s | Hash: %s' \
                   "$TORRENT_NAME" "$size_gb" "$free_gb" "$margin_gb" "$SAVE_PATH" "$INFO_HASH" | json_escape_oneline)
    json_plain=$(printf '{"content":"%s"}' "$content_line")

    HTTP2=$(curl -sS -w "%{http_code}" -o /tmp/discord2.out \
      -H "Content-Type: application/json" -d "$json_plain" \
      "$DISCORD_WEBHOOK" 2>/tmp/discord2.err || echo "000")
    log "DISCORD HTTP(fallback)=$HTTP2"
    [ -s /tmp/discord2.err ] && log "DISCORD ERR(fallback)=$(cat /tmp/discord2.err)"
    [ -s /tmp/discord2.out ] && log "DISCORD OUT(fallback)=$(cat /tmp/discord2.out)"
    rm -f /tmp/discord2.out /tmp/discord2.err || true
  fi

  rm -f /tmp/discord.out /tmp/discord.err || true
}

FREE_BYTES="$(df -PB1 "$SAVE_PATH" | awk 'NR==2{print $4}')"
MARGIN_BYTES="$(to_bytes_from_gb "$MARGIN_GB")"
LIMIT=$(( FREE_BYTES - MARGIN_BYTES )); [ "$LIMIT" -lt 0 ] && LIMIT=0

log "ARGS name='$TORRENT_NAME' size=$TORRENT_SIZE save='$SAVE_PATH' hash=$INFO_HASH"
log "FS free=$(b2gb "$FREE_BYTES") GB, margin=$MARGIN_GB GB, limit=$(b2gb "$LIMIT") GB"
log "CONF webhook_set=$( [ -n "$DISCORD_WEBHOOK" ] && echo yes || echo no ), dry_run=$DRY_RUN"

if [ "$TORRENT_SIZE" -le 0 ] 2>/dev/null; then
  log "SIZE=0 — skip"
  exit 0
fi

if [ "$TORRENT_SIZE" -gt "$LIMIT" ]; then
  log "NO SPACE — deleting torrent (or DRY_RUN)"
  discord_send

  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN=1 -> skipping qB API"
    exit 0
  fi

  COOKIE_JAR="$(mktemp)"
  LOGIN_HTTP=$(curl -sS -w "%{http_code}" -o /dev/null -c "$COOKIE_JAR" \
    -d "username=$QB_USER&password=$QB_PASS" \
    "${QB_URL%/}/api/v2/auth/login" || echo "000")
  log "LOGIN HTTP=$LOGIN_HTTP"

  DEL_HTTP=$(curl -sS -w "%{http_code}" -o /dev/null -b "$COOKIE_JAR" \
    --data-urlencode "hashes=$INFO_HASH" \
    --data "deleteFiles=false" \
    "${QB_URL%/}/api/v2/torrents/delete" || echo "000")
  log "DELETE HTTP=$DEL_HTTP"
  rm -f "$COOKIE_JAR"
  exit 0
else
  log "FITS — doing nothing"
  exit 0
fi
