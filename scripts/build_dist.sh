#!/usr/bin/env bash
# Rebuild dist/nyyo-key-scan-kit.zip. Refuses to package anything that looks like a secret:
#  1. forbidden files (.env, private keys, certificates, reports, downloaded binaries, clones);
#  2. a gitleaks scan of the staged kit with the kit's own rules (Docker or bin/gitleaks);
#  3. a regex pass for common key formats, as a second net.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=dist/nyyo-key-scan-kit.zip
eval "$(grep -E '^(GL_VERSION|GL_IMAGE)=' setup.sh)"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT; D="$STAGE/nyyo-key-scan-kit"
mkdir -p "$D/kit" "$D/tests"
cp setup.sh setup.ps1 INSTALL.md LICENSE "$D/"
cp kit/KIT-README.md "$D/README.md"
cp kit/gitleaks.toml kit/report.tmpl kit/report-head.html kit/report-foot.html "$D/kit/"
cp tests/make_fake_repo.sh "$D/tests/"
cp docs/TESTING.md "$D/TESTING.md"
sed -i 's/\r$//; s/$/\r/' "$D/setup.ps1"          # Windows line endings for the PowerShell script
chmod 755 "$D/setup.sh" "$D/tests/make_fake_repo.sh"

# 1. Forbidden files
BAD="$(find "$D" \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' \
  -o -name 'id_rsa*' -o -name 'id_ed25519*' -o -name '*.kdbx' -o -path '*/reports/*' -o -path '*/bin/*' -o -path '*/work/*' \) -print)"
[ -z "$BAD" ] || { echo "refusing: forbidden file(s) in kit:"; echo "$BAD"; exit 1; }

# 2. gitleaks on the staged kit
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  rc=0; docker run --rm --user "$(id -u):$(id -g)" -v "$D:/scan:ro" "$GL_IMAGE" dir /scan -c /scan/kit/gitleaks.toml \
    --no-banner --redact -v --exit-code 3 -l warn || rc=$?
elif [ -x bin/gitleaks ]; then
  rc=0; bin/gitleaks dir "$D" -c "$D/kit/gitleaks.toml" --no-banner --redact -v --exit-code 3 -l warn || rc=$?
else
  echo "refusing: no gitleaks available to check the kit (start Docker or run ./setup.sh --native once)"; exit 1
fi
[ "$rc" = 3 ] && { echo "refusing: gitleaks found secret-like strings in the kit (values redacted above)"; exit 1; }
[ "$rc" = 0 ] || { echo "refusing: the gitleaks check failed to run (exit $rc)"; exit 1; }
echo "gitleaks check of the staged kit: no leaks"

# 3. Regex second net
if grep -rEn '(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|sk_(live|test)_[A-Za-z0-9]{10,}|sk-(proj-)?[A-Za-z0-9_-]{30,}|xox[abpr]-[0-9A-Za-z-]{10,}|hooks\.slack\.com/services/T[A-Z0-9]+|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY)' "$D"; then
  echo "refusing: secret-like string in kit"; exit 1
fi

rm -f "$OUT"; mkdir -p dist
python3 - "$STAGE" "$OUT" <<'PY'
import os, sys, zipfile
stage, out = sys.argv[1], sys.argv[2]
files = sorted(os.path.relpath(os.path.join(r, f), stage) for r, _, fs in os.walk(stage) for f in fs)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for rel in files:
        full = os.path.join(stage, rel)
        zi = zipfile.ZipInfo(rel, date_time=(2026, 10, 19, 0, 0, 0))   # fixed date: same input, same ZIP
        zi.external_attr = (os.stat(full).st_mode & 0xFFFF) << 16
        zi.create_system = 3  # Unix, so the executable bit on setup.sh survives unzip on Mac/Linux
        zi.compress_type = zipfile.ZIP_DEFLATED
        with open(full, "rb") as fh: z.writestr(zi, fh.read())
PY
unzip -l "$OUT" | tail -n1
sha256sum "$OUT" | cut -d' ' -f1 > "$OUT.sha256"; echo "sha256 $(cat "$OUT.sha256")"
