# Before/after: vibe-coded app rescue

> **For non-technical clients — start here**
>
> **What it does:** Takes a broken AI-generated app (Lovable, Bolt, Cursor, Claude Code…) and makes it safe to share: fix bugs, remove leaked keys, improve accessibility, help you ship.
>
> **Try it in 1 click:** open the [**landing**](https://nyyoautomation.github.io/nyyo-vibe-code-rescue/), click **Before** then **After**. Try pasting HTML into the task box on both.
>
> **Business benefit:** stop losing trust (or leaking keys) because the demo is rough. Fixes from **$49** (1 bug, 1 hour max), audit + production from **$249**. Delivery: 2 / 5 / 10 days by tier.

![Demo](docs/demo.gif)

**Live:** https://nyyoautomation.github.io/nyyo-vibe-code-rescue/  
**Audit:** [audit.md](./audit.md)

## Free 1-click install kit: exposed API key scan
Included free with every package (FREE · 1-click install kit included). Scan your own project for leaked API keys, tokens, passwords and private keys, in the current files **and** the whole git history, and get an HTML report + CSV with every value masked. Runs on your computer, read-only, nothing uploaded.

1. Download [`dist/nyyo-key-scan-kit.zip`](dist/nyyo-key-scan-kit.zip) and unzip it.
2. Mac / Linux: `./setup.sh` · Windows: `powershell -ExecutionPolicy Bypass -File .\setup.ps1`
3. Drag your project folder into the window (or pass a path or a public repo URL). The report opens in your browser.

Scanner: [gitleaks](https://github.com/gitleaks/gitleaks) 8.30.1, pinned (Docker image by digest, or the official binary checked by SHA-256). Beginner guide and troubleshooting: **[INSTALL.md](INSTALL.md)**. Test proof: [docs/TESTING.md](docs/TESTING.md) · [sample report](https://nyyoautomation.github.io/nyyo-vibe-code-rescue/docs/kit-test-proof/sample-report.html) (fake keys).

| Path | Contents |
|---|---|
| `setup.sh`, `setup.ps1` | One-command scan (Mac/Linux, Windows) |
| `kit/` | gitleaks rules (default set + `.env`, OpenAI `sk-proj-`, Supabase) and report templates |
| `tests/` | Fake-key repo generator and the from-scratch kit test |
| `scripts/build_dist.sh` | Builds the ZIP; refuses to package anything that looks like a secret |
| `docs/kit-test-proof/` | Raw output of the from-scratch test |
| `dist/` | The kit ZIP and its SHA-256 |

Licence: MIT (see [LICENSE](LICENSE)). Contact: Nyyo Automation · Remote · Worldwide · LaborX (https://laborx.com/freelancers/users/id475124)

## Hire me
[LaborX — Nyyo Automation](https://laborx.com/freelancers/users/id475124) · [Profile](https://github.com/nyyoautomation)
