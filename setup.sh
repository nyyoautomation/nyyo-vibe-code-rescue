#!/usr/bin/env bash
# Nyyo key scan kit - find exposed API keys in a project folder or git repo (Mac / Linux).
# Free 1-click install kit, MIT licence. Nyyo Automation - Questions? Ask in your order chat.
#
#   ./setup.sh                       asks for the folder (drag it into the Terminal window)
#   ./setup.sh ~/code/my-app         scan a folder (and its git history if it is a git repo)
#   ./setup.sh https://github.com/you/your-public-repo
#
# Options: --native (no Docker), --no-history, --no-open, --fail-on-findings, --help
# Safe to run again: your project is mounted read-only and never modified; each run writes a new
# timestamped report folder; the scanner is only downloaded when missing.
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true

GL_VERSION="8.30.1"
GL_IMAGE="zricethezav/gitleaks:v${GL_VERSION}@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"
# sha256 of the official release archives (gitleaks_8.30.1_checksums.txt)
SHA_darwin_arm64="b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5"
SHA_darwin_x64="dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709"
SHA_linux_arm64="e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080"
SHA_linux_x64="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="$KIT_DIR/kit"
say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

NATIVE=0; HISTORY=1; OPEN=1; FAIL=0; TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --native) NATIVE=1 ;;
    --no-history) HISTORY=0 ;;
    --no-open) OPEN=0 ;;
    --fail-on-findings) FAIL=1 ;;
    -h|--help) usage ;;
    -*) die "Unknown option: $1 (see ./setup.sh --help)" ;;
    *) [ -z "$TARGET" ] || die "Give only one folder or repo URL."; TARGET="$1" ;;
  esac; shift
done
[ -f "$CONF_DIR/gitleaks.toml" ] && [ -f "$CONF_DIR/report.tmpl" ] || die "Kit files missing: run this script from the unzipped kit folder."

if [ -z "$TARGET" ]; then
  [ -t 0 ] || die "Usage: ./setup.sh /path/to/your/project"
  printf 'Drag your project folder into this window (or paste its path or a public git URL), then press Enter:\n> '
  IFS= read -r TARGET
  TARGET="${TARGET%"${TARGET##*[![:space:]]}"}"          # trim trailing spaces
  TARGET="${TARGET#\'}"; TARGET="${TARGET%\'}"; TARGET="${TARGET#\"}"; TARGET="${TARGET%\"}"
  TARGET="${TARGET//\\ / }"                               # Mac drag and drop escapes spaces
  [ -n "$TARGET" ] || die "No folder given."
fi

# ---- 1. Scanner engine: Docker (preferred) or the official binary -------------------------
ENGINE=""
if [ "$NATIVE" = 0 ] && command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then ENGINE=docker
  else warn "Docker is installed but not running (open Docker Desktop to use it). Using the standalone scanner instead."; fi
fi
if [ -z "$ENGINE" ]; then
  [ "$NATIVE" = 1 ] || command -v docker >/dev/null 2>&1 || warn "Docker not found. Using the standalone scanner instead (no Docker needed)."
  ENGINE=native
fi

GL=""
if [ "$ENGINE" = docker ]; then
  if docker image inspect "$GL_IMAGE" >/dev/null 2>&1; then say "Scanner gitleaks $GL_VERSION (Docker) already installed."
  else say "Downloading scanner gitleaks $GL_VERSION (Docker image, pinned by digest)..."; docker pull -q "$GL_IMAGE" >/dev/null; fi
else
  case "$(uname -s)" in Darwin) OS=darwin ;; Linux) OS=linux ;; *) die "Unsupported system $(uname -s). On Windows use setup.ps1." ;; esac
  case "$(uname -m)" in x86_64|amd64) ARCH=x64 ;; arm64|aarch64) ARCH=arm64 ;; *) die "Unsupported CPU $(uname -m)." ;; esac
  GL="$KIT_DIR/bin/gitleaks"
  if [ -x "$GL" ] && "$GL" version 2>/dev/null | grep -q "$GL_VERSION"; then say "Scanner gitleaks $GL_VERSION already installed in bin/."
  else
    command -v curl >/dev/null 2>&1 || die "curl is needed to download the scanner."
    ASSET="gitleaks_${GL_VERSION}_${OS}_${ARCH}.tar.gz"; VAR="SHA_${OS}_${ARCH}"; WANT="${!VAR}"
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    say "Downloading scanner gitleaks $GL_VERSION ($OS/$ARCH) from the official GitHub release..."
    curl -fsSL -o "$TMP/$ASSET" "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VERSION}/${ASSET}" || die "Download failed. Check your internet connection."
    if command -v sha256sum >/dev/null 2>&1; then GOT="$(sha256sum "$TMP/$ASSET" | cut -d' ' -f1)"; else GOT="$(shasum -a 256 "$TMP/$ASSET" | cut -d' ' -f1)"; fi
    [ "$GOT" = "$WANT" ] || die "Checksum mismatch for $ASSET: refusing to install it."
    tar -xzf "$TMP/$ASSET" -C "$TMP" gitleaks
    mkdir -p "$KIT_DIR/bin"; mv -f "$TMP/gitleaks" "$GL"; chmod 755 "$GL"
    say "Checksum verified, scanner installed in bin/."
  fi
fi

# ---- 2. What to scan: local folder, or a fresh clone of a public repo URL ------------------
case "$TARGET" in
  http://*|https://*|git@*)
    NAME="$(basename "${TARGET%/}" .git)"; NAME="$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9._-' '_')"
    CLONE="$KIT_DIR/work/$NAME"
    if [ -d "$CLONE" ]; then
      [ -f "$CLONE/.nyyo-kit-clone" ] || die "$CLONE exists and was not created by this kit: move it away first."
      rm -rf "$CLONE"
    fi
    mkdir -p "$KIT_DIR/work"; say "Cloning $TARGET (full history)..."
    if command -v git >/dev/null 2>&1; then git clone -q "$TARGET" "$CLONE"
    elif [ "$ENGINE" = docker ]; then docker run --rm --user "$(id -u):$(id -g)" --entrypoint git -v "$KIT_DIR/work:/work" "$GL_IMAGE" clone -q "$TARGET" "/work/$NAME"
    else die "git is needed to clone a URL. Install it, or download the repo as a folder and scan that."; fi
    : > "$CLONE/.nyyo-kit-clone"; TARGET="$CLONE" ;;
  *)
    case "$TARGET" in "~/"*) TARGET="$HOME/${TARGET#\~/}" ;; esac
    [ -d "$TARGET" ] || die "Folder not found: $TARGET"
    TARGET="$(cd "$TARGET" && pwd)"
    NAME="$(printf "%s" "$(basename "$TARGET")" | tr -c 'A-Za-z0-9._-' '_')" ;;
esac
case "$TARGET/" in "$KIT_DIR/reports/"*) die "That is a report folder of this kit, not a project." ;; esac

IS_GIT=0; [ -e "$TARGET/.git" ] && IS_GIT=1
STAMP="$(date '+%Y%m%d-%H%M%S')"
OUT="$KIT_DIR/reports/${NAME}-${STAMP}"; n=1
while [ -e "$OUT" ]; do OUT="$KIT_DIR/reports/${NAME}-${STAMP}-$n"; n=$((n+1)); done
mkdir -p "$OUT"

# ---- 3. Scan: current files, then git history ----------------------------------------------
scan() { # $1 = dir|git, $2 = raw output file name
  if [ "$ENGINE" = docker ]; then
    docker run --rm --user "$(id -u):$(id -g)" \
      -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*' \
      -v "$TARGET:/scan:ro" -v "$CONF_DIR:/kit:ro" -v "$OUT:/out" "$GL_IMAGE" \
      "$1" /scan -c /kit/gitleaks.toml --no-banner --redact=80 --exit-code 0 \
      -f template --report-template /kit/report.tmpl -r "/out/$2" -l error
  else
    ( cd "$TARGET" && "$GL" "$1" . -c "$CONF_DIR/gitleaks.toml" --no-banner --redact=80 --exit-code 0 \
      -f template --report-template "$CONF_DIR/report.tmpl" -r "$OUT/$2" -l error )
  fi
}
say "Scanning current files of $NAME..."
scan dir .raw-files.txt
HISTNOTE=""
if [ "$IS_GIT" = 1 ] && [ "$HISTORY" = 1 ]; then
  if [ "$ENGINE" = native ] && ! command -v git >/dev/null 2>&1; then
    HISTNOTE="Git history was NOT scanned: git is not installed on this computer."; warn "$HISTNOTE"; : > "$OUT/.raw-hist.txt"
  else say "Scanning every commit of the git history..."; scan git .raw-hist.txt
    HISTNOTE="Git history scanned: every commit reachable from the repository was checked."; fi
else
  : > "$OUT/.raw-hist.txt"
  if [ "$IS_GIT" = 1 ]; then HISTNOTE="Git history was skipped (--no-history)."
  else HISTNOTE="This folder is not a git repository, so only the current files were scanned."; fi
fi

# ---- 4. Reports: report.html + findings.csv (masked values only) ---------------------------
NF=$(grep -c '^@@HTML@@' "$OUT/.raw-files.txt" || true); NH=$(grep -c '^@@HTML@@' "$OUT/.raw-hist.txt" || true)
NT=$((NF + NH))
sect() { sed -n "s/^@@$1@@//p" "$2" | LC_ALL=C sort | cut -f2-; }   # stable order: file, line, rule, commit
{ printf '\357\273\277'; echo '"where","rule","description","file","line","commit","commit_date","masked_value","fingerprint"'
  sect CSV "$OUT/.raw-files.txt"; sect CSV "$OUT/.raw-hist.txt"; } > "$OUT/findings.csv"
cls() { [ "$1" -gt 0 ] && echo bad || echo ok; }
if [ "$NT" -gt 0 ]; then VERDICT="$NT possible exposed secret(s) found. Rotate the real ones first, then clean the code (see What to do now)."
else VERDICT="No exposed key found by the scanner in this project."; fi
esc() { local s="$1"; s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; printf '%s' "$s"; }
HEAD="$(cat "$CONF_DIR/report-head.html")"; FOOT="$(cat "$CONF_DIR/report-foot.html")"
P="$(esc "$(basename "$TARGET")")"
HEAD="${HEAD//__PROJECT__/$P}"; HEAD="${HEAD//__DATE__/$(date '+%b %-d, %Y, %H:%M %Z')}"
HEAD="${HEAD//__ENGINE__/gitleaks $GL_VERSION ($ENGINE)}"
HEAD="${HEAD//__TOTALCLASS__/$(cls $NT)}"; HEAD="${HEAD//__FILESCLASS__/$(cls $NF)}"; HEAD="${HEAD//__HISTCLASS__/$( [ "$NH" -gt 0 ] && echo warn || echo ok)}"
HEAD="${HEAD//__TOTAL__/$NT}"; HEAD="${HEAD//__FILES__/$NF}"; HEAD="${HEAD//__HIST__/$NH}"
HEAD="${HEAD//__VERDICT__/$VERDICT}"; HEAD="${HEAD//__HISTNOTE__/$HISTNOTE}"; FOOT="${FOOT//__GLVER__/$GL_VERSION}"
{ printf '%s\n' "$HEAD"
  sect HTML "$OUT/.raw-files.txt"; sect HTML "$OUT/.raw-hist.txt"
  [ "$NT" -gt 0 ] || echo '<tr><td colspan="6">Nothing found.</td></tr>'
  printf '%s\n' "$FOOT"; } > "$OUT/report.html"
rm -f "$OUT/.raw-files.txt" "$OUT/.raw-hist.txt"

echo
say "Done: $NT finding(s) ($NF in current files, $NH in git history)."
say "Report: $OUT/report.html"
say "CSV:    $OUT/findings.csv"
if [ "$OPEN" = 1 ] && [ -t 1 ]; then
  if command -v open >/dev/null 2>&1 && [ "$(uname -s)" = Darwin ]; then open "$OUT/report.html"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$OUT/report.html" >/dev/null 2>&1 || true; fi
fi
[ "$FAIL" = 1 ] && [ "$NT" -gt 0 ] && exit 2
exit 0
