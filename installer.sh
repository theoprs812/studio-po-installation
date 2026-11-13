#!/usr/bin/env bash
# Installation du Studio Project Orange (Mac). Dépôt public, il ne contient que l'installation :
# le Studio lui-même est privé, réservé aux élèves invités.
#   curl -fsSL https://raw.githubusercontent.com/theoprs812/studio-po-installation/main/installer.sh | bash
# Étapes : 1. l'outil GitHub + connexion par code  2. téléchargement du Studio  3. son installation.
set -u
PUB="https://raw.githubusercontent.com/theoprs812/studio-po-installation/main"
DOSSIER="$HOME/.editeur"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "== 1/3 Connexion à GitHub"
tmp=$(mktemp)
curl -fsSL "$PUB/github.sh" -o "$tmp" || { echo "ETAT: ERREUR pas de connexion internet"; exit 1; }
bash "$tmp" | tee "$tmp.out"
grep -q "ETAT: OK" "$tmp.out" || exit 0          # CODE pas tapé à temps, ou INVITATION pas acceptée : Claude guide, puis relance

echo "== 2/3 Téléchargement du Studio"
if [[ -d "$DOSSIER/.git" ]]; then
  git -C "$DOSSIER" pull --ff-only --quiet && echo "Studio déjà là, mis à jour."
else
  [[ -d "$DOSSIER" ]] && mv "$DOSSIER" "$DOSSIER.ancien-$(date +%s)"
  gh repo clone theoprs812/editeur "$DOSSIER" -- --quiet || { echo "ETAT: ERREUR téléchargement du Studio"; exit 1; }
  echo "Studio téléchargé dans ~/.editeur."
fi

echo "== 3/3 Installation"
exec bash "$DOSSIER/scripts/installer.sh"
