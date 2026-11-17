#!/usr/bin/env bash
# Connecte l'ordi de l'élève à GitHub pour recevoir le Studio (dépôt privé) et ses mises à jour.
# Claude le lance ; l'élève n'a qu'à taper un code de 8 caractères sur github.com/login/device.
#
#   bash ~/.editeur/scripts/github.sh            vérifie, et connecte si besoin
#   bash ~/.editeur/scripts/github.sh --etat     dit seulement où on en est (une ligne ETAT: ...)
#
# Lignes lues par Claude :
#   ETAT: OK            connecté et invité, les mises à jour passent
#   ETAT: CODE XXXX-XXXX  l'élève tape ce code sur https://github.com/login/device (le script attend)
#   ETAT: INVITATION    connecté, mais l'invitation au Studio n'est pas encore acceptée
#   ETAT: A_CONNECTER   pas encore connecté (avec --etat)
#   ETAT: ERREUR <raison>
set -u
DEPOT="project-orange-dashboard/editeur"
BIN="$HOME/.local/bin"
export PATH="$BIN:/opt/homebrew/bin:/usr/local/bin:$PATH"
ETAT_SEUL=0; [[ "${1:-}" == "--etat" ]] && ETAT_SEUL=1

# 1. L'outil GitHub (gh) : la version officielle, posée dans ~/.local/bin, sans mot de passe.
installer_gh() {
  command -v gh >/dev/null 2>&1 && return 0
  echo "J'installe l'outil GitHub (gh)..."
  local v arch url tmp
  v=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)
  [[ -n "$v" ]] || { echo "ETAT: ERREUR pas de connexion internet"; exit 1; }
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) url="https://github.com/cli/cli/releases/download/v$v/gh_${v}_macOS_arm64.zip" ;;
    Darwin-*) url="https://github.com/cli/cli/releases/download/v$v/gh_${v}_macOS_amd64.zip" ;;
    Linux-x86_64) url="https://github.com/cli/cli/releases/download/v$v/gh_${v}_linux_amd64.tar.gz" ;;
    Linux-aarch64|Linux-arm64) url="https://github.com/cli/cli/releases/download/v$v/gh_${v}_linux_arm64.tar.gz" ;;
    *) echo "ETAT: ERREUR système non prévu ($(uname -s))"; exit 1 ;;
  esac
  tmp=$(mktemp -d); mkdir -p "$BIN"
  curl -fsSL "$url" -o "$tmp/gh.pkg" || { echo "ETAT: ERREUR téléchargement de gh"; exit 1; }
  if [[ "$url" == *.zip ]]; then (cd "$tmp" && unzip -q gh.pkg); else tar -xzf "$tmp/gh.pkg" -C "$tmp"; fi
  cp "$(find "$tmp" -type f -path '*/bin/gh' | head -1)" "$BIN/gh" && chmod +x "$BIN/gh"
  rm -rf "$tmp"
  command -v gh >/dev/null 2>&1 || { echo "ETAT: ERREUR gh introuvable après installation"; exit 1; }
}

connecte() { gh auth status --hostname github.com >/dev/null 2>&1; }
invite()   { gh api "repos/$DEPOT" --silent >/dev/null 2>&1; }

installer_gh

if ! connecte; then
  if [[ $ETAT_SEUL == 1 ]]; then echo "ETAT: A_CONNECTER"; exit 0; fi
  # Connexion par code : gh affiche un code et attend que l'élève le tape sur github.com/login/device.
  sortie=$(mktemp)
  GH_BROWSER=true gh auth login --web --hostname github.com --git-protocol https --skip-ssh-key </dev/null >"$sortie" 2>&1 &
  pid=$!
  for _ in $(seq 1 30); do grep -q "code" "$sortie" && break; sleep 1; done
  code=$(grep -oE '[A-Z0-9]{4}-[A-Z0-9]{4}' "$sortie" | head -1)
  [[ -n "$code" ]] || { cat "$sortie"; echo "ETAT: ERREUR pas de code reçu"; kill $pid 2>/dev/null; exit 1; }
  echo "ETAT: CODE $code"
  echo "Ouvre https://github.com/login/device, tape le code $code, puis clique sur Authorize."
  open "https://github.com/login/device" 2>/dev/null || xdg-open "https://github.com/login/device" 2>/dev/null || true
  wait $pid || { echo "ETAT: ERREUR le code a expiré (15 min). Relance la connexion."; exit 1; }
fi

gh auth setup-git --hostname github.com >/dev/null 2>&1   # git passe par ce compte pour les mises à jour

if ! invite; then
  echo "Connecté en tant que $(gh api user --jq .login 2>/dev/null)."
  echo "ETAT: INVITATION"
  echo "Ouvre le mail de GitHub « invited you to collaborate », clique sur Accept invitation, puis relance."
  exit 0
fi

rm -f "$HOME/.editeur/.github-a-connecter"
echo "Connecté en tant que $(gh api user --jq .login 2>/dev/null), accès au Studio OK."
echo "ETAT: OK"
