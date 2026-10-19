# Key scan kit: test report

Tested on **Oct 19, 2026** on the build box: Linux x86_64, Docker Engine 26.1, PowerShell 7.4, gitleaks 8.30.1.
Raw output of every step: [`kit-test-proof/`](kit-test-proof/). The test is scripted: `tests/run_kit_test.sh` (repo only).

## From scratch
1. The gitleaks Docker image was **deleted** first, the shipped ZIP was unzipped into an **empty folder** (no `bin/`,
   no `reports/`), and `tests/make_fake_repo.sh` built a throwaway repo with **7 clearly fake values** (all contain
   `FAKE`, none works anywhere): an AWS key, a GitHub token, a Stripe **test** key, a Slack webhook, an RSA private
   key block, and an untracked `.env` with an OpenAI `sk-proj-` key and a password. Commit 2 "removes" the AWS key, so it
   only survives in the git history. A `.env.example` with placeholders and a `node_modules/` copy are there as traps.
2. `./setup.sh <repo>` pulled the pinned image, scanned the files and the history, and wrote `report.html` + `findings.csv`.
3. The same scan was repeated: `setup.sh` again (Docker), `setup.sh --native` twice (download + SHA-256 check, then reuse),
   `setup.ps1` under PowerShell 7.4 with Docker, then `-Native` twice.
4. A public repo URL was scanned twice (clone, scan, re-clone on the second run).

## Results
| Check | Result |
|---|---|
| Findings on the fake repo | **12 of 12 expected**: 7 in current files, 5 in git history, nothing extra |
| AWS key deleted in commit 2 | Reported from **git history** only |
| `.env.example` placeholders, `node_modules/` | Not reported (as intended) |
| Masking | No full fake value in any HTML, CSV or console log; prefixes kept (`AKIA...`, `ghp_FAKE...`, `sk_test...`) |
| Scanned project | Unchanged after 9 runs (file hashes, HEAD and `git status` identical) |
| Second runs | Image / binary reused, new timestamped report folder each time, identical findings |
| Bash vs PowerShell, Docker vs native | Same 12 findings, same order, same HTML table |
| Exit codes | 0 on every run |
| `scripts/build_dist.sh` | Builds a clean copy; **refuses** when a fake AWS key is pasted into `INSTALL.md` (gitleaks check) and when a fake OpenAI key is added to the kit config (regex net) |

See [kit-test-proof/11_checks.txt](kit-test-proof/11_checks.txt), [12_build_dist_refusal.txt](kit-test-proof/12_build_dist_refusal.txt),
the [sample report](kit-test-proof/sample-report.html) and [sample CSV](kit-test-proof/sample-findings.csv).

## Not tested
- Docker Desktop on a real Mac or Windows PC, the macOS / Windows gitleaks binaries (their SHA-256 values come from the
  official checksums file but were not executed here), and Windows PowerShell 5.1 (the script avoids PowerShell 7-only syntax).
- Very large repositories (performance).
