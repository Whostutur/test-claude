#!/usr/bin/env bash
# Réactive tous les paquets de debloat-marina.txt.
# Usage : ./restaurer.sh <ip-de-la-tele> [liste]
set -u
TV="${1:?usage: ./restaurer.sh <ip-de-la-tele> [liste]}"
LISTE="${2:-$(dirname "$0")/debloat-marina.txt}"
case "$TV" in *:*) ;; *) TV="$TV:5555" ;; esac
adb connect "$TV" >/dev/null 2>&1
adb -s "$TV" get-state >/dev/null 2>&1 || { echo "Pas de connexion ADB à $TV." >&2; exit 1; }
for p in $(grep -v -E '^\s*(#|$)' "$LISTE" | awk '{print $1}'); do
  echo "$p: $(adb -s "$TV" shell pm enable --user 0 "$p" </dev/null | tr -d '\r')"
done
echo "Attends 15 s puis redémarre : adb -s $TV shell sync; adb -s $TV reboot"
