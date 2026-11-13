# Connecte l'ordi de l'élève à GitHub (Windows) pour recevoir le Studio (dépôt privé) et ses mises à jour.
#   powershell -NoProfile -ExecutionPolicy Bypass -File github.ps1 [--etat]
# Mêmes lignes « ETAT: ... » que github.sh : OK, CODE XXXX-XXXX, INVITATION, A_CONNECTER, ERREUR <raison>.
$EtatSeul = $args -contains "--etat"
$Depot = "theoprs812/editeur"
$Bin = Join-Path $env:USERPROFILE ".local\bin"
$env:Path = "$Bin;$env:ProgramFiles\GitHub CLI;$env:Path"
function A($c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }

if (-not (A gh)) {
  Write-Host "J'installe l'outil GitHub (gh)..."
  try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/cli/cli/releases/latest"
    $url = ($rel.assets | Where-Object { $_.name -like "*_windows_amd64.zip" } | Select-Object -First 1).browser_download_url
    $tmp = Join-Path $env:TEMP ("gh-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $tmp, $Bin | Out-Null
    Invoke-WebRequest $url -OutFile "$tmp\gh.zip" -UseBasicParsing
    Expand-Archive "$tmp\gh.zip" $tmp -Force
    Copy-Item (Get-ChildItem $tmp -Recurse -Filter gh.exe | Select-Object -First 1).FullName "$Bin\gh.exe" -Force
    Remove-Item -Recurse -Force $tmp
    $u = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($u -notlike "*$Bin*") { [Environment]::SetEnvironmentVariable("Path", "$Bin;$u", "User") }
  } catch { Write-Host "ETAT: ERREUR téléchargement de gh"; exit 1 }
}

function Connecte { gh auth status --hostname github.com *> $null; return $LASTEXITCODE -eq 0 }
function Invite { gh api "repos/$Depot" --silent *> $null; return $LASTEXITCODE -eq 0 }

if (-not (Connecte)) {
  if ($EtatSeul) { Write-Host "ETAT: A_CONNECTER"; exit 0 }
  $sortie = Join-Path $env:TEMP "gh-login.txt"
  $env:GH_BROWSER = "cmd /c rem"
  $p = Start-Process gh -ArgumentList "auth login --web --hostname github.com --git-protocol https --skip-ssh-key" `
        -RedirectStandardError $sortie -RedirectStandardOutput "$sortie.out" -NoNewWindow -PassThru
  $code = $null
  for ($k = 0; $k -lt 30 -and -not $code; $k++) {
    Start-Sleep 1
    $t = (Get-Content $sortie, "$sortie.out" -Raw -ErrorAction SilentlyContinue) -join "`n"
    if ($t -match '([A-Z0-9]{4}-[A-Z0-9]{4})') { $code = $Matches[1] }
  }
  if (-not $code) { Write-Host "ETAT: ERREUR pas de code reçu"; $p | Stop-Process -ErrorAction SilentlyContinue; exit 1 }
  Write-Host "ETAT: CODE $code"
  Write-Host "Ouvre https://github.com/login/device, tape le code $code, puis clique sur Authorize."
  Start-Process "https://github.com/login/device"
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { Write-Host "ETAT: ERREUR le code a expiré (15 min). Relance la connexion."; exit 1 }
}

gh auth setup-git --hostname github.com *> $null

if (-not (Invite)) {
  Write-Host ("Connecté en tant que " + (gh api user --jq .login) + ".")
  Write-Host "ETAT: INVITATION"
  Write-Host "Ouvre le mail de GitHub « invited you to collaborate », clique sur Accept invitation, puis relance."
  exit 0
}
Remove-Item (Join-Path $env:USERPROFILE ".editeur\.github-a-connecter") -ErrorAction SilentlyContinue
Write-Host ("Connecté en tant que " + (gh api user --jq .login) + ", accès au Studio OK.")
Write-Host "ETAT: OK"
