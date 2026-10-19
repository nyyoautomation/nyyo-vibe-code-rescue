#!/usr/bin/env bash
# From-scratch test of the shipped ZIP (used on the build box; needs docker, pwsh optional).
#   tests/run_kit_test.sh [path/to/nyyo-key-scan-kit.zip]
# Writes raw logs and checks to docs/kit-test-proof/.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; ZIP="${1:-$REPO/dist/nyyo-key-scan-kit.zip}"
PROOF="$REPO/docs/kit-test-proof"; rm -rf "$PROOF"; mkdir -p "$PROOF"
PWSH="$(command -v pwsh || echo /tmp/pwsh/pwsh)"
W="$(mktemp -d /tmp/keyscan-test.XXXX)"; K="$W/nyyo-key-scan-kit"; T="$W/fake-app"; V="$W/fake-values.txt"
eval "$(grep -E '^(GL_VERSION|GL_IMAGE)=' "$REPO/setup.sh")"
PASS=0; FAILN=0
check() { if eval "$2"; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1"; FAILN=$((FAILN+1)); fi; }
rows() { sed '1s/^\xEF\xBB\xBF//' "$1" | tr -d '\r' | sed 1d; }
snap() { (cd "$T" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum; git -C "$T" rev-parse HEAD; git -C "$T" status --porcelain) ; }
last() { ls -d "$K"/reports/*/ | sort | tail -1; }
run() { local name="$1"; shift; { echo "\$ $*"; echo; "$@" 2>&1; echo; echo "[exit code $?]"; } | sed 's/\x1b\[[0-9;]*m//g' > "$PROOF/$name"; }

{
  echo "Date: $(date '+%b %-d, %Y, %H:%M %Z')"; echo "System: $(uname -sm)"
  echo "Docker: $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
  echo "PowerShell: $("$PWSH" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo none)"
  echo "Kit ZIP: $(basename "$ZIP") sha256 $(sha256sum "$ZIP" | cut -d' ' -f1)"
  echo "Scratch folder: $W (empty before unzip)"
} > "$PROOF/00_environment.txt"

# ---- From scratch: no scanner image, no binary, fresh unzip, fresh fake repo ----
docker rmi -f "$GL_IMAGE" "${GL_IMAGE%@*}" >/dev/null 2>&1
echo "gitleaks image present before test: $(docker image inspect "$GL_IMAGE" >/dev/null 2>&1 && echo yes || echo no)" >> "$PROOF/00_environment.txt"
(cd "$W" && unzip -q "$ZIP") && ls -la "$K" >> "$PROOF/00_environment.txt"
bash "$K/tests/make_fake_repo.sh" "$T" "$V" > "$PROOF/01_fake_repo.txt" 2>&1
{ echo; echo "git log:"; git -C "$T" log --oneline --stat; echo; echo "untracked:"; git -C "$T" status --porcelain; } >> "$PROOF/01_fake_repo.txt"
snap > "$W/before.snap"

run 02_setup_sh_docker_first_run.txt "$K/setup.sh" "$T" --no-open; R1="$(last)"
run 03_setup_sh_docker_second_run.txt "$K/setup.sh" "$T" --no-open; R2="$(last)"
run 04_setup_sh_native_first_run.txt "$K/setup.sh" "$T" --native --no-open; R3="$(last)"
run 05_setup_sh_native_second_run.txt "$K/setup.sh" "$T" --native --no-open; R4="$(last)"
rm -rf "$K/bin"
if [ -x "$PWSH" ]; then
  run 06_setup_ps1_docker_run.txt "$PWSH" -NoProfile -File "$K/setup.ps1" "$T" -NoOpen; R5="$(last)"
  run 07_setup_ps1_native_first_run.txt "$PWSH" -NoProfile -File "$K/setup.ps1" "$T" -Native -NoOpen; R6="$(last)"
  run 08_setup_ps1_native_second_run.txt "$PWSH" -NoProfile -File "$K/setup.ps1" "$T" -Native -NoOpen; R7="$(last)"
fi
run 09_setup_sh_public_url.txt "$K/setup.sh" https://github.com/nyyoautomation/nyyo-vibe-code-rescue --no-open; RU="$(last)"
run 10_setup_sh_public_url_again.txt "$K/setup.sh" https://github.com/nyyoautomation/nyyo-vibe-code-rescue --no-open
snap > "$W/after.snap"
cp "$R1/report.html" "$PROOF/sample-report.html"; cp "$R1/findings.csv" "$PROOF/sample-findings.csv"

# ---- Checks ----
cat > "$W/expected.txt" <<'X'
current files,env-file-secret,.env,2
current files,env-file-secret,.env,3
current files,github-pat,src/config.js,2
current files,openai-project-key,.env,2
current files,private-key,deploy/id_rsa,1
current files,slack-webhook-url,README.md,2
current files,stripe-access-token,src/config.js,3
git history,aws-access-token,src/config.js,2
git history,github-pat,src/config.js,3
git history,private-key,deploy/id_rsa,1
git history,slack-webhook-url,README.md,2
git history,stripe-access-token,src/config.js,4
X
rows "$R1/findings.csv" | python3 -c "import csv,sys;[print(','.join([r[0],r[1],r[3],r[4]])) for r in csv.reader(sys.stdin)]" | sort > "$W/got.txt"
{
  echo "Checks on the fake repo ($(wc -l < "$V") fake values, 2 commits, untracked .env)"; echo
  check "12 expected findings found (7 current files, 5 git history), nothing missing, nothing extra" "diff -u '$W/expected.txt' '$W/got.txt'"
  check "AWS key removed in commit 2 is reported from git history only" "grep -q '^git history,aws-access-token' '$W/got.txt' && ! grep -q '^current files,aws' '$W/got.txt'"
  check ".env.example placeholders not reported" "! grep -q 'env.example' '$W/got.txt'"
  check "node_modules/ not reported" "! grep -q node_modules '$W/got.txt'"
  check "masking: no full fake value appears in any report (HTML or CSV, all runs)" "! grep -rqF -f '$V' '$K/reports'"
  check "masking: no full fake value appears in any console log" "! grep -rqF -f '$V' '$PROOF'"
  check "masked values keep a recognisable prefix (AKIA..., ghp_FAKE..., sk_test...)" "grep -q 'AKIA\.\.\.' '$R1/findings.csv' && grep -q 'ghp_FAKE\.\.\.' '$R1/findings.csv' && grep -q 'sk_test\.\.\.' '$R1/findings.csv'"
  check "scanned project unchanged after all runs (file hashes, HEAD, git status)" "diff -q '$W/before.snap' '$W/after.snap' >/dev/null"
  check "second Docker run reuses the image (no download)" "grep -q 'already installed' '$PROOF/03_setup_sh_docker_second_run.txt'"
  check "first native run downloads and verifies the checksum" "grep -q 'Checksum verified' '$PROOF/04_setup_sh_native_first_run.txt'"
  check "second native run reuses the binary" "grep -q 'already installed in bin' '$PROOF/05_setup_sh_native_second_run.txt'"
  check "each run wrote its own report folder (nothing overwritten)" "[ \$(ls -d '$K'/reports/fake-app-*/ | wc -l) -ge 4 ] && [ '$R1' != '$R2' ]"
  check "bash: Docker run 2 and native runs give identical findings" "diff -q <(rows '$R1/findings.csv') <(rows '$R2/findings.csv') >/dev/null && diff -q <(rows '$R1/findings.csv') <(rows '$R3/findings.csv') >/dev/null && diff -q <(rows '$R1/findings.csv') <(rows '$R4/findings.csv') >/dev/null"
  if [ -n "${R5:-}" ]; then
    check "PowerShell: Docker and native runs give the same findings as bash" "diff -q <(rows '$R1/findings.csv') <(rows '$R5/findings.csv') >/dev/null && diff -q <(rows '$R1/findings.csv') <(rows '$R6/findings.csv') >/dev/null && diff -q <(rows '$R1/findings.csv') <(rows '$R7/findings.csv') >/dev/null"
    check "PowerShell: first native run verifies the checksum, second reuses the binary" "grep -q 'Checksum verified' '$PROOF/07_setup_ps1_native_first_run.txt' && grep -q 'already installed in bin' '$PROOF/08_setup_ps1_native_second_run.txt'"
    check "PowerShell: same HTML table as bash" "diff -q <(grep '<tr><td><span' '$R1/report.html') <(grep '<tr><td><span' '$R5/report.html') >/dev/null"
  fi
  check "every run exited with code 0" "! grep -h '^\[exit code' '$PROOF'/0[2-9]_*.txt '$PROOF'/10_*.txt | grep -qv 'exit code 0'"
  check "public URL: repo cloned with full history, both scans ran, re-run re-clones cleanly" "grep -q 'Cloning' '$PROOF/09_setup_sh_public_url.txt' && grep -q 'Scanning every commit' '$PROOF/09_setup_sh_public_url.txt' && grep -q 'Done:' '$PROOF/10_setup_sh_public_url_again.txt' && [ -f '$RU/report.html' ]"
  echo "      note: 0 findings on the public demo repo. Its decorative placeholder in before/ (sk-demo-LEAKED-KEY-DO-NOT-USE-12345)"
  echo "      is low-entropy and matches no provider format, so gitleaks rightly treats it as not a real key."
} > "$PROOF/11_checks.txt" 2>&1

# ---- build_dist must refuse secrets ----
B="$W/build-copy"; mkdir -p "$B"
(cd "$REPO" && tar --exclude=./.git --exclude=./reports --exclude=./bin --exclude=./work --exclude=./dist -cf - .) | (cd "$B" && tar -xf -)
{
  echo "build_dist.sh refusal tests (on a copy of the repo)"; echo
  echo "--- A. clean copy: must build"; (cd "$B" && bash scripts/build_dist.sh) 2>&1 | tail -3; echo "[exit code ${PIPESTATUS[0]}]"
  cp "$B/INSTALL.md" "$W/INSTALL.bak"
  echo; echo "--- B. a fake AWS key pasted into INSTALL.md: must refuse"
  printf '\nexample: %s\n' "AKIA""FAKEQ7ZTESTW3KXY" >> "$B/INSTALL.md"
  (cd "$B" && bash scripts/build_dist.sh) 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'refusing|leaks found|Finding' ; echo "[exit code ${PIPESTATUS[0]}]"
  cp "$W/INSTALL.bak" "$B/INSTALL.md"
  echo; echo "--- C. a fake OpenAI key in the kit config: must refuse"
  printf '\n# %s\n' "sk-""proj-FAKEtestu8jzPde0IgxLd6GncfBAepfJBd0Kh8oO" >> "$B/kit/gitleaks.toml"
  (cd "$B" && bash scripts/build_dist.sh) 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'refusing|leaks found' ; echo "[exit code ${PIPESTATUS[0]}]"
} > "$PROOF/12_build_dist_refusal.txt" 2>&1
grep -qF -f "$V" "$PROOF/12_build_dist_refusal.txt" && sed -i -f <(sed 's/[]\/$*.^[]/\\&/g; s/.*/s\/&\/[FAKE VALUE REMOVED FROM LOG]\/g/' "$V") "$PROOF/12_build_dist_refusal.txt"

cat "$PROOF/11_checks.txt"; echo; cat "$PROOF/12_build_dist_refusal.txt"
rm -rf "$W"
