# Nyyo key scan kit (free 1-click install kit)

Find leaked API keys, tokens, passwords and private keys in a project folder or git repo, in the current files and in
the whole git history. You get `report.html` and `findings.csv`, with every value masked.

- **Mac / Linux:** `./setup.sh` (then drag your project folder into the window)
- **Windows:** `powershell -ExecutionPolicy Bypass -File .\setup.ps1`

Step-by-step guide for beginners, options and troubleshooting: **INSTALL.md**.

| File | What it is |
|---|---|
| `setup.sh`, `setup.ps1` | One-command scan: installs gitleaks 8.30.1 (Docker image pinned by digest, or the official binary checked by SHA-256), scans, writes the reports |
| `kit/gitleaks.toml` | Rules: the gitleaks default set plus checks for `.env` files, new OpenAI keys and Supabase secret keys |
| `kit/report.tmpl`, `kit/report-*.html` | Report templates (masked values only) |
| `tests/make_fake_repo.sh` | Builds a throwaway repo with clearly fake keys to try the kit |
| `TESTING.md` | How the kit was tested |

Runs 100 % on your computer, read-only on your project. Nothing is uploaded. MIT licence (see LICENSE).

Bonus kit of the vibe-code rescue gig: https://nyyoautomation.github.io/nyyo-vibe-code-rescue/
Nyyo Automation · Remote · Worldwide · LaborX (https://laborx.com/freelancers/users/id475124)
