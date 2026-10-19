#!/usr/bin/env bash
# Build a throwaway git repo full of CLEARLY FAKE keys to test the scanner.
# Every value contains FAKE / test and is assembled at run time, so this file itself holds no
# secret-looking string. None of these values works anywhere.
#   tests/make_fake_repo.sh <new-folder> [file-to-write-the-fake-values-to]
set -euo pipefail
DEST="${1:?usage: make_fake_repo.sh <new-folder> [values-file]}"; VALUES="${2:-/dev/null}"
[ ! -e "$DEST" ] || { echo "$DEST already exists" >&2; exit 1; }
mkdir -p "$DEST/src" "$DEST/deploy" "$DEST/node_modules/some-lib"; cd "$DEST"
git init -q; git config user.name "Fake Tester"; git config user.email "tester@example.invalid"
git config commit.gpgsign false

AWS="AKIA""FAKEQ7ZTESTW3KXY"
GHP="ghp""_FAKEtestK3y9Qm2Lx7Vb4Nc8Zp1Rt6Ws0YuHj5"
STRIPE="sk""_test_FAKE4eC39HqLyjWDarjtT1zdp7dc"
SLACK="https://hooks.slack.com/services/""T0FAKE0001/B0FAKE0002/u8jzPde0IgxLd6GncfBAepfJ"
OPENAI="sk-""proj-FAKEtestu8jzPde0IgxLd6GncfBAepfJBd0Kh8oO"
DBPW="FAKEpw-u8jzPde0IgxLd6GncfB"
PEMBODY="FAKEtestFAKEtestMIIEowIBAAKCAQEAu8jzPde0IgxLd6GncfBAepfJBd0Kh8oOFAKEtestFAKEtestQm2Lx7Vb4Nc8Zp1Rt6Ws0YuHj5"
BEGIN="-----BEGIN RSA PRIV""ATE KEY-----"; END="-----END RSA PRIV""ATE KEY-----"
printf '%s\n' "$AWS" "$GHP" "$STRIPE" "$SLACK" "$OPENAI" "$DBPW" "$PEMBODY" > "$VALUES"

# Commit 1: a typical vibe-coded app with keys pasted into the code.
cat > src/config.js <<JS
// FAKE TEST KEYS for a scanner test. Not real, they work nowhere.
export const AWS_ACCESS_KEY_ID = "$AWS";
export const GITHUB_TOKEN = "$GHP";
export const STRIPE_KEY = "$STRIPE";
JS
printf '# Deploy notes\nAlerts go to %s\n' "$SLACK" > README.md
printf '%s\n%s\n%s\n' "$BEGIN" "$PEMBODY" "$END" > deploy/id_rsa
printf 'node_modules/\n' > .gitignore
git add -A; git commit -qm "First version of the app"

# Commit 2: the AWS key is "removed"... but it stays in the git history.
grep -v AWS_ACCESS_KEY_ID src/config.js > src/config.tmp && mv src/config.tmp src/config.js
git commit -qam "Remove AWS key"

# Not committed: a real-looking .env (forgotten in .gitignore) and a placeholder .env.example.
printf '# FAKE TEST VALUES\nOPENAI_API_KEY=%s\nDB_PASSWORD="%s"\n' "$OPENAI" "$DBPW" > .env
printf 'OPENAI_API_KEY=your-openai-key-here\nDB_PASSWORD=changeme-in-production\n' > .env.example
# Third-party code: ignored by the kit on purpose.
printf 'const k = "%s";\n' "$GHP" > node_modules/some-lib/index.js
echo "Fake repo ready in $DEST (2 commits, $(wc -l < "$VALUES" 2>/dev/null || echo 7) fake values)."
