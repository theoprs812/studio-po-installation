# Installation du Studio Project Orange (Windows). Dépôt public, il ne contient que l'installation.
#   irm https://raw.githubusercontent.com/theoprs812/studio-po-installation/main/installer.ps1 | iex
$Pub = "https://raw.githubusercontent.com/theoprs812/studio-po-installation/main"
$Dossier = Join-Path $env:USERPROFILE ".editeur"
$env:Path = "$env:USERPROFILE\.local\bin;$env:ProgramFiles\GitHub CLI;$env:ProgramFiles\Git\cmd;$env:Path"

Write-Host "== 1/3 Connexion à GitHub"
$gs = Join-Path $env:TEMP "github.ps1"
Invoke-WebRequest "$Pub/github.ps1" -OutFile $gs -UseBasicParsing
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $gs | Tee-Object -Variable lignes
if (-not ($lignes -match "ETAT: OK")) { exit 0 }

Write-Host "== 2/3 Téléchargement du Studio"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements | Out-Null; $env:Path = "$env:ProgramFiles\Git\cmd;$env:Path" }
if (Test-Path (Join-Path $Dossier ".git")) { git -C $Dossier pull --ff-only --quiet; Write-Host "Studio déjà là, mis à jour." }
else {
  if (Test-Path $Dossier) { Rename-Item $Dossier "$Dossier.ancien-$(Get-Date -Format yyyyMMddHHmmss)" }
  gh repo clone theoprs812/editeur $Dossier -- --quiet
  if ($LASTEXITCODE -ne 0) { Write-Host "ETAT: ERREUR téléchargement du Studio"; exit 1 }
  Write-Host "Studio téléchargé dans .editeur."
}

Write-Host "== 3/3 Installation"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dossier "scripts\installer.ps1")
