# Exposed API key scan: one-command install (Mac, Windows, Linux)

This free kit checks a project for **leaked API keys, tokens, passwords and private keys**, in the
current files **and** in the whole git history, and gives you a clear **HTML report** plus a **CSV**.
It is the free 1-click install kit that comes with the vibe-code rescue gig. You don't need to know the
command line: copy and paste the commands below.

- **Time needed:** about 5 minutes the first time (the scanner download is about 30 MB).
- **Cost:** free. The scanner is [gitleaks](https://github.com/gitleaks/gitleaks) 8.30.1 (MIT licence), pinned to an exact version.
- **Private:** everything runs on your computer. Nothing is uploaded, nothing is sent to Nyyo Automation, and the
  scanner never calls the services to "test" a key.
- **Safe:** your project is opened **read-only**. The kit never changes, deletes or commits anything in it.
- **Masked:** the report shows only the first characters of each value (`AKIA...`, `ghp_FAKE...`), so the report
  itself does not become a leak.

> What you get at the end: `reports/<your-project>-<date>/report.html` (opens in your browser) and `findings.csv`
> (opens in Excel, Numbers or Google Sheets).

---

## Step 1. Install Docker Desktop (recommended) - or skip it

The kit prefers Docker because it runs the scanner in a sealed box. **No Docker? The kit still works:** it downloads
the official gitleaks program instead and checks its SHA-256 fingerprint before using it. If you skip Docker, go to Step 2.

### Mac
1. Go to https://www.docker.com/products/docker-desktop/ and download **Docker Desktop for Mac**.
   Pick **Apple chip** for M1/M2/M3/M4 Macs, **Intel chip** for older ones (Apple menu > About This Mac tells you which).
2. Open the downloaded `.dmg` and drag **Docker** into **Applications**.
3. Open **Docker** from Applications. Accept the terms. You can skip sign-in: no Docker account is needed.
4. Wait until Docker Desktop shows **Engine running**.

### Windows 10/11
1. Download **Docker Desktop for Windows** from the same page and run the installer. Keep **Use WSL 2** ticked.
2. Restart Windows if asked. Open **Docker Desktop** and wait for **Engine running**. Sign-in is optional; skip it.

### Linux (Ubuntu / Debian)
Install Docker Engine following https://docs.docker.com/engine/install/ , then:
```bash
sudo usermod -aG docker "$USER"   # lets you run docker without sudo; log out and back in afterwards
```

## Step 2. Unzip the kit and open a terminal in its folder

1. Unzip `nyyo-key-scan-kit.zip`. You get a folder `nyyo-key-scan-kit`.
2. Open a terminal in that folder:
   - **Mac:** open **Terminal** (Cmd + Space, type `Terminal`, Enter). Type `cd ` (with a space at the end),
     drag the `nyyo-key-scan-kit` folder into the Terminal window, press **Enter**.
   - **Windows:** open the folder in File Explorer, click the address bar, type `powershell`, press **Enter**.
   - **Linux:** right-click inside the folder > **Open in Terminal**.

## Step 3. Run the scan

### Mac / Linux
```bash
./setup.sh
```
It asks for your project: **drag your project folder into the Terminal window** and press **Enter**.
You can also give it directly:
```bash
./setup.sh ~/Documents/my-app
./setup.sh https://github.com/you/your-public-repo     # public repos only; for a private one, scan your local copy
```

### Windows
```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```
Paste the path of your project folder (in File Explorer: right-click the folder > **Copy as path**) and press **Enter**. Or:
```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1 "C:\Users\you\Documents\my-app"
```

The report opens in your browser when the scan is done (Mac and Windows). The terminal also prints where it is.

### Options
| Mac / Linux | Windows | What it does |
|---|---|---|
| `--native` | `-Native` | Don't use Docker, use the standalone gitleaks program |
| `--no-history` | `-NoHistory` | Scan only the current files, not the git history (faster on huge repos) |
| `--no-open` | `-NoOpen` | Don't open the report automatically |
| `--fail-on-findings` | `-FailOnFindings` | Exit with code 2 when something is found (for CI or scripts) |

**Running it again is safe.** Each run writes a new timestamped report folder and never overwrites an old one.
The scanner is downloaded only the first time.

## Step 4. Read the report

- **Current files** (red): the key is in your project right now. Anyone with the code, or with your website's
  JavaScript, can read it.
- **Git history** (amber): the key was removed from the files but is still in an old commit. Anyone who can clone the
  repo can still find it.
- **Masked value:** the first characters, to recognise which key it is (`sk_live...` vs `sk_test...`).

What to do, in this order (also written at the bottom of the report):
1. **Rotate** every real key in the provider's dashboard: create a new one, revoke the old one. This is the step that
   actually closes the leak.
2. Move secrets into environment variables or your host's secret settings. Keys used in browser code are public by design:
   call the API from a server function instead.
3. Add `.env` to `.gitignore`, keep only a `.env.example` with placeholders.
4. Rewriting git history is optional, and only worth it after rotation.

Want it done for you? The vibe-code rescue gig fixes it (keys moved out, code cleaned, checked again): see the
[demo page](https://nyyoautomation.github.io/nyyo-vibe-code-rescue/). Questions? Ask in your order chat.

## Try it on a fake project first (optional)

The kit includes a generator for a throwaway repo full of **clearly fake** keys:
```bash
bash tests/make_fake_repo.sh /tmp/fake-app && ./setup.sh /tmp/fake-app
```
You should see 12 findings: 7 in current files and 5 in git history (including an AWS key that was "removed" in the
second commit), while `.env.example` placeholders and `node_modules/` are correctly ignored.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Mac: `permission denied: ./setup.sh` | Run `chmod +x setup.sh` once, or start it with `bash setup.sh`. |
| Mac: "cannot be opened because the developer cannot be verified" (native mode) | The kit downloads gitleaks with `curl`, which normally avoids this. If it still happens: System Settings > Privacy & Security > **Allow Anyway**, then run again. Or use Docker. |
| `Docker is installed but not running` | Open Docker Desktop and wait for **Engine running**, then run again. Or ignore it: the kit falls back to the standalone scanner. |
| Docker: `permission denied ... docker.sock` (Linux) | Run `sudo usermod -aG docker "$USER"`, log out and back in. |
| Windows: "running scripts is disabled on this system" | Use the exact command above (`powershell -ExecutionPolicy Bypass -File .\setup.ps1`). It changes nothing permanently. |
| Windows: Docker asks to share the drive / "Mounts denied" | Docker Desktop > Settings > Resources > File sharing: add the drive or folder of your project. Or use `-Native`. |
| `Folder not found` | Drag the folder again, or put the path in quotes if it contains spaces: `./setup.sh "/Users/you/My App"`. |
| `Git history was NOT scanned: git is not installed` | Mac: run `xcode-select --install`. Windows: install Git for Windows. Or use Docker, which includes git. |
| `Checksum mismatch` | The download was corrupted or altered: the kit refuses to run it. Try again later, or use Docker. |
| Clone fails for a URL | Private repos need your login: clone it yourself, then scan the local folder. |
| Too many findings in test files | Fake values in tests can match. Add the fingerprint from `findings.csv` (one per line) to a `.gitleaksignore` file at the root of your project. |
| The scan is slow | Very large histories take time. Use `--no-history` / `-NoHistory` for a quick pass on current files. |

## What the kit checks
- The full **gitleaks default rule set** (AWS, Google, GitHub, GitLab, Stripe, Slack, OpenAI, Anthropic, Twilio,
  SendGrid, private keys, JWTs, generic API keys: 222 rules in total).
- **Nyyo extras** for apps built with AI tools: secrets in `.env` files (committed or not), new OpenAI key formats
  (`sk-proj-...`), Supabase secret keys. `.env.example` placeholders and dependency folders (`node_modules`, `vendor`,
  virtual envs) are ignored.

## Honest limits
- A scanner finds **known patterns**. An empty report does not prove there is no secret (for example a password
  written in plain words, or a key split across lines).
- Some findings are false positives (test values, examples). Check each line before rotating.
- The kit does not test whether a key still works, on purpose: that would send your key to the provider.
- Tested on Linux (Docker and standalone, bash and PowerShell 7). Not yet tested on a real Mac or a Windows PC, nor
  with Windows PowerShell 5.1. See [docs/TESTING.md](docs/TESTING.md).

Nyyo Automation · Remote · Worldwide · Questions? Ask in your order chat.
