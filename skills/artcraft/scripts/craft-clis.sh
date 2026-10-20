#!/usr/bin/env bash
# Install, update and check the ArtCraft Crafting Apps command-line tools (macOS, Linux).
#
#   craft-clis.sh list                    apps this script knows
#   craft-clis.sh check   [app ...]       installed vs latest release
#   craft-clis.sh install [app ...]       install missing CLIs, update outdated ones
#   craft-clis.sh update  [app ...]       same as install
#
# Env: ARTCRAFT_BIN_DIR (default ~/.local/bin), GITHUB_TOKEN (optional, avoids rate limits).
# Every download is checked against the release's SHA256SUMS.txt; on macOS the binary must
# also pass Gatekeeper (notarized Developer ID). Nothing from an archive runs except
# `<app>-cli --version` after it is verified.
set -euo pipefail

APPS=(photocraft vectorcraft filmcraft effectcraft pdfcraft deckcraft gridcraft wordcraft
      lightcraft designcraft soundcraft cadcraft figcraft)
ORG="storytold"
BIN_DIR="${ARTCRAFT_BIN_DIR:-$HOME/.local/bin}"

die() { printf 'craft-clis: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*" >&2; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

is_known_app() {
  local a
  for a in "${APPS[@]}"; do [[ "$a" == "$1" ]] && return 0; done
  return 1
}

curl_gh() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl --proto '=https' --tlsv1.2 -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
  else
    curl --proto '=https' --tlsv1.2 -fsSL "$@"
  fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# Latest tag via the releases/latest redirect: no JSON parsing, no API quota.
latest_version() {
  local url
  url=$(curl --proto '=https' --tlsv1.2 -fsSI -o /dev/null -w '%{redirect_url}' \
        "https://github.com/$ORG/$1/releases/latest") || return 1
  local tag="${url##*/tag/}"
  [[ "$tag" =~ ^v?[0-9]+(\.[0-9]+)*$ ]] || return 1
  printf '%s\n' "${tag#v}"
}

installed_version() {
  local bin="$BIN_DIR/$1-cli"
  [[ -x "$bin" ]] || return 1
  "$bin" --version 2>/dev/null | head -1 | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1
}

# 0 if $1 < $2 (dotted numeric versions)
version_lt() {
  [[ "$1" == "$2" ]] && return 1
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | head -1)" == "$1" ]]
}

platform() {
  local os arch
  os=$(uname -s); arch=$(uname -m)
  case "$os" in
    Darwin) echo "macos" ;;
    Linux)
      case "$arch" in
        x86_64|amd64) echo "linux-x86_64" ;;
        aarch64|arm64) echo "linux-aarch64" ;;
        riscv64) echo "linux-riscv64" ;;
        *) die "unsupported Linux architecture: $arch" ;;
      esac ;;
    *) die "unsupported OS: $os (use craft-clis.ps1 on Windows)" ;;
  esac
}

install_one() {
  local app="$1" plat="$2" ver="$3"
  local tag="v$ver" asset member
  case "$plat" in
    macos) asset="$app-cli-$ver-macos-universal.zip"; member="$app-cli-$ver-macos-universal/$app-cli" ;;
    linux-*) asset="$app-$ver-$plat.tar.gz"; member="$app-$ver-$plat/bin/$app-cli" ;;
  esac
  local base="https://github.com/$ORG/$app/releases/download/$tag"
  local tmp; tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  log "  downloading $asset"
  curl_gh -o "$tmp/SHA256SUMS.txt" "$base/SHA256SUMS.txt" || { log "  no SHA256SUMS.txt for $app $tag"; return 1; }
  curl_gh -o "$tmp/$asset" "$base/$asset" || { log "  no asset $asset in $app $tag"; return 1; }

  local want got
  want=$(awk -v f="$asset" '$2==f || $2=="*"f {print $1; exit}' "$tmp/SHA256SUMS.txt")
  [[ -n "$want" ]] || { log "  $asset is not listed in SHA256SUMS.txt"; return 1; }
  got=$(sha256_of "$tmp/$asset")
  [[ "$want" == "$got" ]] || { log "  CHECKSUM MISMATCH for $asset (want $want, got $got)"; return 1; }

  mkdir "$tmp/x"
  case "$plat" in
    macos) ditto -x -k "$tmp/$asset" "$tmp/x" ;;
    linux-*) tar -xzf "$tmp/$asset" -C "$tmp/x" --no-same-owner "$member" ;;
  esac
  local bin="$tmp/x/$member"
  [[ -f "$bin" && ! -L "$bin" ]] || { log "  $member not found in $asset"; return 1; }

  if [[ "$plat" == macos ]]; then
    local gk
    gk=$(spctl --assess --type install -vv "$bin" 2>&1) || { log "  Gatekeeper rejected $app-cli: $gk"; return 1; }
    grep -q 'source=Notarized Developer ID' <<<"$gk" || { log "  $app-cli is not notarized: $gk"; return 1; }
  fi

  chmod 0755 "$bin"
  mkdir -p "$BIN_DIR"
  # Atomic replace: copy beside the target, then rename over it.
  cp "$bin" "$BIN_DIR/.$app-cli.new"
  mv -f "$BIN_DIR/.$app-cli.new" "$BIN_DIR/$app-cli"
  log "  installed $BIN_DIR/$app-cli ($("$BIN_DIR/$app-cli" --version 2>/dev/null | head -1))"
}

select_apps() {
  if [[ $# -eq 0 ]]; then printf '%s\n' "${APPS[@]}"; return; fi
  local a
  for a in "$@"; do
    a="${a%-cli}"; a=$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')
    is_known_app "$a" || die "unknown app: $a (try: list)"
    printf '%s\n' "$a"
  done
}

cmd_check() {
  local app cur new status rc=0
  printf '%-12s %-10s %-10s %s\n' APP INSTALLED LATEST STATUS
  while read -r app; do
    cur=$(installed_version "$app" || true)
    new=$(latest_version "$app" || true)
    if [[ -z "$new" ]]; then status="latest-unknown"
    elif [[ -z "$cur" ]]; then status="missing"; rc=1
    elif version_lt "$cur" "$new"; then status="outdated"; rc=1
    else status="ok"; fi
    printf '%-12s %-10s %-10s %s\n' "$app" "${cur:--}" "${new:--}" "$status"
  done < <(select_apps "$@")
  return $rc
}

cmd_install() {
  need curl; need awk
  local plat; plat=$(platform)
  [[ "$plat" == macos ]] && { need ditto; need spctl; } || need tar
  local app cur new failed=()
  while read -r app; do
    new=$(latest_version "$app") || { log "$app: cannot read latest release"; failed+=("$app"); continue; }
    cur=$(installed_version "$app" || true)
    if [[ -n "$cur" ]] && ! version_lt "$cur" "$new"; then
      log "$app-cli $cur is up to date"; continue
    fi
    log "$app-cli ${cur:-not installed} -> $new"
    install_one "$app" "$plat" "$new" </dev/null || failed+=("$app")
  done < <(select_apps "$@")

  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) log "note: $BIN_DIR is not on PATH; add it to your shell profile." ;; esac
  if [[ ${#failed[@]} -gt 0 ]]; then die "failed: ${failed[*]}"; fi
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    list) printf '%s\n' "${APPS[@]}" ;;
    check) cmd_check "$@" ;;
    install|update) cmd_install "$@" ;;
    ""|-h|--help|help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) die "unknown command: $cmd (install | update | check | list)" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
