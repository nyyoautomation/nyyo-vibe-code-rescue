<#
Nyyo key scan kit - find exposed API keys in a project folder or git repo (Windows).
Free 1-click install kit, MIT licence. Nyyo Automation - LaborX (https://laborx.com/freelancers/users/id475124)

  powershell -ExecutionPolicy Bypass -File .\setup.ps1                       (asks for the folder)
  powershell -ExecutionPolicy Bypass -File .\setup.ps1 C:\code\my-app
  powershell -ExecutionPolicy Bypass -File .\setup.ps1 https://github.com/you/your-public-repo

Options: -Native (no Docker), -NoHistory, -NoOpen, -FailOnFindings
Safe to run again: your project is mounted read-only and never modified; each run writes a new
timestamped report folder; the scanner is only downloaded when missing.
Works with Windows PowerShell 5.1 and PowerShell 7 (also on Mac / Linux).
#>
param(
  [Parameter(Position = 0)][string]$Target = "",
  [switch]$Native, [switch]$NoHistory, [switch]$NoOpen, [switch]$FailOnFindings
)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$GlVersion = '8.30.1'
$GlImage = "zricethezav/gitleaks:v$GlVersion@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"
$Sha = @{  # official gitleaks_8.30.1_checksums.txt
  'windows_x64'  = 'd29144deff3a68aa93ced33dddf84b7fdc26070add4aa0f4513094c8332afc4e'
  'windows_arm64'= 'b95f5e4f5c425cedca7ee203d9afd29597e692c4924a12ed42f970537c72cc0f'
  'darwin_arm64' = 'b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5'
  'darwin_x64'   = 'dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709'
  'linux_arm64'  = 'e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080'
  'linux_x64'    = '551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb'
}
$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfDir = Join-Path $KitDir 'kit'
function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }
$OnWindows = ($env:OS -eq 'Windows_NT')
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)
$Utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path (Join-Path $ConfDir 'gitleaks.toml')) -or -not (Test-Path (Join-Path $ConfDir 'report.tmpl'))) {
  Die 'Kit files missing: run this script from the unzipped kit folder.' }

if (-not $Target) {
  $Target = Read-Host 'Paste the path of your project folder (or a public git URL), then press Enter'
  $Target = $Target.Trim().Trim('"').Trim("'")
  if (-not $Target) { Die 'No folder given.' }
}

# ---- 1. Scanner engine: Docker (preferred) or the official binary ----
$Engine = ''
$HasDocker = [bool](Get-Command docker -ErrorAction SilentlyContinue)
if (-not $Native -and $HasDocker) {
  & docker info *> $null
  if ($LASTEXITCODE -eq 0) { $Engine = 'docker' }
  else { Warn 'Docker is installed but not running (start Docker Desktop to use it). Using the standalone scanner instead.' }
}
if (-not $Engine) {
  if (-not $Native -and -not $HasDocker) { Warn 'Docker not found. Using the standalone scanner instead (no Docker needed).' }
  $Engine = 'native'
}
$DockerUser = @()
if (-not $OnWindows -and $Engine -eq 'docker') { $DockerUser = @('--user', "$(& id -u):$(& id -g)") }

$Gl = ''
if ($Engine -eq 'docker') {
  & docker image inspect $GlImage *> $null
  if ($LASTEXITCODE -eq 0) { Say "Scanner gitleaks $GlVersion (Docker) already installed." }
  else {
    Say "Downloading scanner gitleaks $GlVersion (Docker image, pinned by digest)..."
    & docker pull -q $GlImage | Out-Null
    if ($LASTEXITCODE -ne 0) { Die 'Docker could not download the scanner image. Check your internet connection.' }
  }
} else {
  if ($OnWindows) { $os = 'windows' } elseif ($IsMacOS) { $os = 'darwin' } else { $os = 'linux' }
  $archName = "$env:PROCESSOR_ARCHITECTURE"
  if (-not $archName) { try { $archName = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() } catch { $archName = 'X64' } }
  if ($archName -match 'ARM64') { $arch = 'arm64' } else { $arch = 'x64' }
  $key = "${os}_$arch"
  $exe = if ($os -eq 'windows') { 'gitleaks.exe' } else { 'gitleaks' }
  $Gl = Join-Path (Join-Path $KitDir 'bin') $exe
  $ok = $false
  if (Test-Path $Gl) { $v = & $Gl version 2>$null; if ("$v" -match [regex]::Escape($GlVersion)) { $ok = $true } }
  if ($ok) { Say "Scanner gitleaks $GlVersion already installed in bin\." }
  else {
    $ext = if ($os -eq 'windows') { 'zip' } else { 'tar.gz' }
    $asset = "gitleaks_${GlVersion}_$key.$ext"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("nyyo-gl-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $file = Join-Path $tmp $asset
    Say "Downloading scanner gitleaks $GlVersion ($key) from the official GitHub release..."
    try { Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/gitleaks/gitleaks/releases/download/v$GlVersion/$asset" -OutFile $file -ErrorAction Stop }
    catch { Die 'Download failed. Check your internet connection.' }
    $got = (Get-FileHash -Algorithm SHA256 -Path $file).Hash.ToLower()
    if ($got -ne $Sha[$key]) { Remove-Item -Recurse -Force $tmp; Die "Checksum mismatch for ${asset}: refusing to install it." }
    if ($ext -eq 'zip') { Expand-Archive -Path $file -DestinationPath $tmp -Force } else { & tar -xzf $file -C $tmp gitleaks }
    New-Item -ItemType Directory -Path (Join-Path $KitDir 'bin') -Force | Out-Null
    Move-Item -Force (Join-Path $tmp $exe) $Gl
    if (-not $OnWindows) { & chmod 755 $Gl }
    Remove-Item -Recurse -Force $tmp
    Say 'Checksum verified, scanner installed in bin\.'
  }
}

# ---- 2. What to scan: local folder, or a fresh clone of a public repo URL ----
$HasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
if ($Target -match '^(https?://|git@)') {
  $Name = [IO.Path]::GetFileNameWithoutExtension($Target.TrimEnd('/')) -replace '[^A-Za-z0-9._-]', '_'
  $work = Join-Path $KitDir 'work'; $clone = Join-Path $work $Name
  if (Test-Path $clone) {
    if (-not (Test-Path (Join-Path $clone '.nyyo-kit-clone'))) { Die "$clone exists and was not created by this kit: move it away first." }
    Remove-Item -Recurse -Force $clone
  }
  New-Item -ItemType Directory -Path $work -Force | Out-Null
  Say "Cloning $Target (full history)..."
  if ($HasGit) { & git clone -q $Target $clone }
  elseif ($Engine -eq 'docker') { & docker run --rm @DockerUser --entrypoint git -v "${work}:/work" $GlImage clone -q $Target "/work/$Name" }
  else { Die 'git is needed to clone a URL. Install Git for Windows, or download the repo as a folder and scan that.' }
  if ($LASTEXITCODE -ne 0) { Die 'Clone failed (private repo? Download it and scan the folder instead).' }
  New-Item -ItemType File -Path (Join-Path $clone '.nyyo-kit-clone') -Force | Out-Null
  $Target = $clone
} else {
  if (-not (Test-Path -PathType Container $Target)) { Die "Folder not found: $Target" }
  $Target = (Resolve-Path $Target).ProviderPath.TrimEnd('\', '/')
  $Name = (Split-Path -Leaf $Target) -replace '[^A-Za-z0-9._-]', '_'
}
if ($Target.StartsWith((Join-Path $KitDir 'reports'))) { Die 'That is a report folder of this kit, not a project.' }

$IsGit = Test-Path (Join-Path $Target '.git')
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path (Join-Path $KitDir 'reports') "$Name-$Stamp"; $n = 1
while (Test-Path $Out) { $Out = Join-Path (Join-Path $KitDir 'reports') "$Name-$Stamp-$n"; $n++ }
New-Item -ItemType Directory -Path $Out -Force | Out-Null

# ---- 3. Scan: current files, then git history ----
function Invoke-Scan($mode, $raw) {
  $common = @('-c', '__CONF__', '--no-banner', '--redact=80', '--exit-code', '0', '-f', 'template', '--report-template', '__TMPL__', '-r', '__OUT__', '-l', 'error')
  if ($Engine -eq 'docker') {
    $a = $common -replace '__CONF__', '/kit/gitleaks.toml' -replace '__TMPL__', '/kit/report.tmpl' -replace '__OUT__', "/out/$raw"
    & docker run --rm @DockerUser -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e 'GIT_CONFIG_VALUE_0=*' `
      -v "${Target}:/scan:ro" -v "${ConfDir}:/kit:ro" -v "${Out}:/out" $GlImage $mode /scan @a
  } else {
    $a = @(); foreach ($x in $common) { $a += $x.Replace('__CONF__', (Join-Path $ConfDir 'gitleaks.toml')).Replace('__TMPL__', (Join-Path $ConfDir 'report.tmpl')).Replace('__OUT__', (Join-Path $Out $raw)) }
    Push-Location $Target; try { & $Gl $mode . @a } finally { Pop-Location }
  }
  if ($LASTEXITCODE -ne 0) { Die "The scanner stopped with an error ($mode scan)." }
}
$rawF = Join-Path $Out '.raw-files.txt'; $rawH = Join-Path $Out '.raw-hist.txt'
Say "Scanning current files of $Name..."
Invoke-Scan 'dir' '.raw-files.txt'
if ($IsGit -and -not $NoHistory) {
  if ($Engine -eq 'native' -and -not $HasGit) {
    $HistNote = 'Git history was NOT scanned: git is not installed on this computer.'; Warn $HistNote
    [IO.File]::WriteAllText($rawH, '', $Utf8)
  } else {
    Say 'Scanning every commit of the git history...'; Invoke-Scan 'git' '.raw-hist.txt'
    $HistNote = 'Git history scanned: every commit reachable from the repository was checked.'
  }
} else {
  [IO.File]::WriteAllText($rawH, '', $Utf8)
  if ($IsGit) { $HistNote = 'Git history was skipped (-NoHistory).' } else { $HistNote = 'This folder is not a git repository, so only the current files were scanned.' }
}

# ---- 4. Reports: report.html + findings.csv (masked values only) ----
$linesF = @([IO.File]::ReadAllLines($rawF, $Utf8)); $linesH = @([IO.File]::ReadAllLines($rawH, $Utf8))
$NF = @($linesF | Where-Object { $_.StartsWith('@@HTML@@') }).Count
$NH = @($linesH | Where-Object { $_.StartsWith('@@HTML@@') }).Count
$NT = $NF + $NH
$csv = @('"where","rule","description","file","line","commit","commit_date","masked_value","fingerprint"')
function Get-Section($lines, $tag) {  # stable order: file, line, rule, commit (ordinal sort, same as LC_ALL=C sort)
  [string[]]$x = @($lines | Where-Object { $_.StartsWith($tag) } | ForEach-Object { $_.Substring($tag.Length) })
  [Array]::Sort($x, [StringComparer]::Ordinal)
  @($x | ForEach-Object { $_.Substring($_.IndexOf("`t") + 1) })
}
$csv += Get-Section $linesF '@@CSV@@'; $csv += Get-Section $linesH '@@CSV@@'
[IO.File]::WriteAllText((Join-Path $Out 'findings.csv'), (($csv -join "`n") + "`n"), $Utf8Bom)
function Cls($c) { if ($c -gt 0) { 'bad' } else { 'ok' } }
if ($NT -gt 0) { $Verdict = "$NT possible exposed secret(s) found. Rotate the real ones first, then clean the code (see What to do now)." }
else { $Verdict = 'No exposed key found by the scanner in this project.' }
$proj = (Split-Path -Leaf $Target).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
$now = Get-Date
$date = $now.ToString('MMM d, yyyy, HH:mm', [Globalization.CultureInfo]::InvariantCulture) + ' (UTC' + $now.ToString('zzz') + ')'
$head = [IO.File]::ReadAllText((Join-Path $ConfDir 'report-head.html'), $Utf8)
$foot = [IO.File]::ReadAllText((Join-Path $ConfDir 'report-foot.html'), $Utf8)
$histCls = if ($NH -gt 0) { 'warn' } else { 'ok' }
$head = $head.Replace('__PROJECT__', $proj).Replace('__DATE__', $date).Replace('__ENGINE__', "gitleaks $GlVersion ($Engine)")
$head = $head.Replace('__TOTALCLASS__', (Cls $NT)).Replace('__FILESCLASS__', (Cls $NF)).Replace('__HISTCLASS__', $histCls)
$head = $head.Replace('__TOTAL__', "$NT").Replace('__FILES__', "$NF").Replace('__HIST__', "$NH").Replace('__VERDICT__', $Verdict).Replace('__HISTNOTE__', $HistNote)
$foot = $foot.Replace('__GLVER__', $GlVersion)
$rows = @(Get-Section $linesF '@@HTML@@') + @(Get-Section $linesH '@@HTML@@')
if ($NT -eq 0) { $rows = @('<tr><td colspan="6">Nothing found.</td></tr>') }
[IO.File]::WriteAllText((Join-Path $Out 'report.html'), ($head + "`n" + ($rows -join "`n") + "`n" + $foot), $Utf8)
Remove-Item -Force $rawF, $rawH

Write-Host ''
Say "Done: $NT finding(s) ($NF in current files, $NH in git history)."
Say "Report: $(Join-Path $Out 'report.html')"
Say "CSV:    $(Join-Path $Out 'findings.csv')"
if (-not $NoOpen -and $OnWindows) { Start-Process (Join-Path $Out 'report.html') }
if ($FailOnFindings -and $NT -gt 0) { exit 2 }
exit 0
