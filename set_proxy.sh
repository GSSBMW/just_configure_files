#!/usr/bin/env bash

# sc_proxy.sh
# Usage:
#   ./sc_proxy.sh           # start proxy
#   ./sc_proxy.sh start     # start proxy
#   ./sc_proxy.sh stop      # stop proxy
#   ./sc_proxy.sh status    # show status
#
# Notes:
# - If you EXECUTE this script, it cannot modify the parent shell environment.
#   It will print export/unset commands for you to run in the same shell.
# - If you SOURCE this script, it will export/unset proxy variables in-place.

(return 0 2>/dev/null) && __SC_SOURCED=1 || __SC_SOURCED=0
if [ "${__SC_SOURCED}" -eq 0 ]; then
  set -euo pipefail
fi

SSH_USER="sanshang"
SSH_HOST="remote_host_name"
SSH_PORT=12345
SOCKS_PORT=18080
HTTP_PORT=8119

BEGIN_MARK="# >>> sc_proxy managed >>>"
END_MARK="# <<< sc_proxy managed <<<"

is_macos() {
  [ "$(uname -s)" = "Darwin" ]
}

log() {
  printf '%s\n' "$*"
}

find_privoxy_conf() {
  if is_macos; then
    if command -v brew >/dev/null 2>&1; then
      BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
      if [ -n "${BREW_PREFIX}" ] && [ -f "${BREW_PREFIX}/etc/privoxy/config" ]; then
        printf '%s\n' "${BREW_PREFIX}/etc/privoxy/config"
        return 0
      fi
    fi
    for p in /opt/homebrew/etc/privoxy/config /usr/local/etc/privoxy/config /etc/privoxy/config; do
      if [ -f "$p" ]; then
        printf '%s\n' "$p"
        return 0
      fi
    done
  else
    for p in /etc/privoxy/config /usr/local/etc/privoxy/config; do
      if [ -f "$p" ]; then
        printf '%s\n' "$p"
        return 0
      fi
    done
  fi
  return 1
}

install_privoxy_if_needed() {
  if command -v privoxy >/dev/null 2>&1; then
    return 0
  fi

  if is_macos && command -v brew >/dev/null 2>&1 && brew list --formula privoxy >/dev/null 2>&1; then
    return 0
  fi

  log "== Install privoxy if needed =="
  if is_macos; then
    if command -v brew >/dev/null 2>&1; then
      brew install privoxy
    else
      log "ERROR: Homebrew not found; install privoxy manually." >&2
      exit 1
    fi
  else
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y privoxy
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y privoxy
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y privoxy
    else
      log "ERROR: No supported package manager found; install privoxy manually." >&2
      exit 1
    fi
  fi
}

restart_privoxy() {
  if is_macos; then
    brew services restart privoxy
  elif command -v systemctl >/dev/null 2>&1; then
    sudo systemctl restart privoxy.service
  elif command -v service >/dev/null 2>&1; then
    sudo service privoxy restart
  else
    log "ERROR: Unsupported service manager; restart privoxy manually." >&2
    exit 1
  fi
}

stop_privoxy() {
  if is_macos; then
    brew services stop privoxy || true
  elif command -v systemctl >/dev/null 2>&1; then
    sudo systemctl stop privoxy.service || true
  elif command -v service >/dev/null 2>&1; then
    sudo service privoxy stop || true
  else
    pkill privoxy 2>/dev/null || true
  fi
}

remove_managed_block() {
  conf="$1"
  tmp_file="$(mktemp)"
  awk -v begin="$BEGIN_MARK" -v end="$END_MARK" -v http_port="$HTTP_PORT" -v socks_port="$SOCKS_PORT" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    skip { next }
    $0 == ("listen-address 127.0.0.1:" http_port) { next }
    $0 == ("forward-socks5 / 127.0.0.1:" socks_port " .") { next }
    { print }
  ' "$conf" > "$tmp_file"
  cat "$tmp_file" > "$conf"
  rm -f "$tmp_file"
}

write_managed_block() {
  conf="$1"
  remove_managed_block "$conf"
  cat >> "$conf" <<EOCFG
$BEGIN_MARK
listen-address 127.0.0.1:${HTTP_PORT}
forward-socks5 / 127.0.0.1:${SOCKS_PORT} .
$END_MARK
EOCFG
}

export_proxy_vars() {
  export http_proxy="http://127.0.0.1:${HTTP_PORT}"
  export https_proxy="http://127.0.0.1:${HTTP_PORT}"
  export HTTP_PROXY="http://127.0.0.1:${HTTP_PORT}"
  export HTTPS_PROXY="http://127.0.0.1:${HTTP_PORT}"
}

unset_proxy_vars() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
}

print_export_commands() {
  cat <<EOENV
export http_proxy=http://127.0.0.1:${HTTP_PORT}
export https_proxy=http://127.0.0.1:${HTTP_PORT}
export HTTP_PROXY=http://127.0.0.1:${HTTP_PORT}
export HTTPS_PROXY=http://127.0.0.1:${HTTP_PORT}
EOENV
}

print_unset_commands() {
  cat <<EOUNSET
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
EOUNSET
}

start_tunnel() {
  log "== Start SSH SOCKS5 tunnel =="
  pkill -f "ssh -D ${SOCKS_PORT}" 2>/dev/null || true
  ssh -D "${SOCKS_PORT}" -p "${SSH_PORT}" -N -f "${SSH_USER}@${SSH_HOST}"
}

stop_tunnel() {
  log "== Stop SSH SOCKS5 tunnel =="
  pkill -f "ssh -D ${SOCKS_PORT}" 2>/dev/null || true
}

show_status() {
  log "== Status =="
  if pgrep -f "ssh -D ${SOCKS_PORT}" >/dev/null 2>&1; then
    log "SSH SOCKS5 tunnel: running on 127.0.0.1:${SOCKS_PORT}"
  else
    log "SSH SOCKS5 tunnel: stopped"
  fi

  if command -v lsof >/dev/null 2>&1 && lsof -iTCP:"${HTTP_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    log "HTTP proxy (privoxy): listening on 127.0.0.1:${HTTP_PORT}"
  else
    log "HTTP proxy (privoxy): not listening on 127.0.0.1:${HTTP_PORT}"
  fi

  log "Shell proxy vars in current process view:"
  env | grep -i '^http_proxy=\|^https_proxy=\|^HTTP_PROXY=\|^HTTPS_PROXY=' || true
}

start_proxy() {
  install_privoxy_if_needed
  CONF="$(find_privoxy_conf)"
  log "== Privoxy config == $CONF"

  start_tunnel

  log "== Update privoxy config =="
  if is_macos; then
    remove_managed_block "$CONF"
    write_managed_block "$CONF"
  else
    sudo sh -c 'tmp_file="$(mktemp)"; awk -v begin="'"$BEGIN_MARK"'" -v end="'"$END_MARK"'" -v http_port="'"$HTTP_PORT"'" -v socks_port="'"$SOCKS_PORT"'" '\''
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      skip { next }
      $0 == ("listen-address 127.0.0.1:" http_port) { next }
      $0 == ("forward-socks5 / 127.0.0.1:" socks_port " .") { next }
      { print }
    '\'' "'"$CONF"'" > "$tmp_file" && cat "$tmp_file" > "'"$CONF"'" && rm -f "$tmp_file"'
    sudo tee -a "$CONF" >/dev/null <<EOCFG
$BEGIN_MARK
listen-address 127.0.0.1:${HTTP_PORT}
forward-socks5 / 127.0.0.1:${SOCKS_PORT} .
$END_MARK
EOCFG
  fi

  log "== Restart privoxy =="
  restart_privoxy

  log "== Export proxy env vars =="
  if [ "${__SC_SOURCED}" -eq 1 ]; then
    export_proxy_vars
    log "Done. Proxy vars exported in this shell."
  else
    log "Done. Run these in the SAME shell if needed:"
    print_export_commands
  fi

  log
  log "Test with: curl https://ifconfig.me"
}

stop_proxy() {
  CONF="$(find_privoxy_conf 2>/dev/null || true)"

  stop_tunnel

  if [ -n "${CONF}" ] && [ -f "${CONF}" ]; then
    log "== Clean privoxy config =="
    if is_macos; then
      remove_managed_block "$CONF"
    else
      sudo sh -c 'tmp_file="$(mktemp)"; awk -v begin="'"$BEGIN_MARK"'" -v end="'"$END_MARK"'" -v http_port="'"$HTTP_PORT"'" -v socks_port="'"$SOCKS_PORT"'" '\''
        $0 == begin { skip=1; next }
        $0 == end { skip=0; next }
        skip { next }
        $0 == ("listen-address 127.0.0.1:" http_port) { next }
        $0 == ("forward-socks5 / 127.0.0.1:" socks_port " .") { next }
        { print }
      '\'' "'"$CONF"'" > "$tmp_file" && cat "$tmp_file" > "'"$CONF"'" && rm -f "$tmp_file"'
    fi
  fi

  log "== Stop privoxy =="
  stop_privoxy

  log "== Clear proxy env vars =="
  if [ "${__SC_SOURCED}" -eq 1 ]; then
    unset_proxy_vars
    log "Done. Proxy vars unset in this shell."
  else
    log "Done. Run this in the SAME shell if needed:"
    print_unset_commands
  fi
}

ACTION="${1:-start}"
case "$ACTION" in
  start)
    start_proxy
    ;;
  stop)
    stop_proxy
    ;;
  status)
    show_status
    ;;
  *)
    printf 'Usage: %s [start|stop|status]\n' "${0##*/}" >&2
    exit 1
    ;;
esac
