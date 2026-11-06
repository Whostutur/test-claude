#!/usr/bin/env bash
# Répare la touche Input/Source (HDMI) après un debloat qui a désactivé ou désinstallé un paquet de trop.
#
# Usage : ./reparer-hdmi.sh <ip-de-la-tele>          # propose seulement les paquets liés aux entrées/HDMI
#         ./reparer-hdmi.sh <ip-de-la-tele> --tout   # remet TOUT ce que le premier debloat a enlevé
#
# Rien n'est désinstallé : le script réactive (pm enable) ou réinstalle depuis la partition système
# (cmd package install-existing) les paquets que tu valides un par un.
set -u
TV="${1:?usage: ./reparer-hdmi.sh <ip-de-la-tele> [--tout]}"
TOUT="${2:-}"
case "$TV" in *:*) ;; *) TV="$TV:5555" ;; esac
command -v adb >/dev/null || { echo "adb introuvable : installe Android platform-tools d'abord." >&2; exit 1; }
adb connect "$TV" >/dev/null 2>&1
adb -s "$TV" get-state >/dev/null 2>&1 || { echo "Pas de connexion ADB à $TV (lance d'abord diagnostic.sh)." >&2; exit 1; }
s() { adb -s "$TV" shell "$@" </dev/null 2>&1 | tr -d '\r'; }
demande() { local r; read -r -p "$1 [O/n] " r </dev/tty; case "$r" in n|N|non|NON) return 1 ;; *) return 0 ;; esac; }

DESACTIVES=$(s pm list packages -d | sed 's/^package://' | sort)
DESINSTALLES=$(comm -23 <(s pm list packages -u | sed 's/^package://' | sort) \
                        <(s pm list packages    | sed 's/^package://' | sort))

# Paquets vers lesquels Android envoie des touches « globales » (dont KEYCODE_TV_INPUT sur beaucoup de télés).
GLOBAL=$( { s dumpsys window; s dumpsys window policy; } | grep -A40 -E 'mKeyMapping|GlobalKey' \
          | grep -oE 'ComponentInfo\{[^/}]+' | sed 's/ComponentInfo{//' | sort -u)

# Noms qui trahissent la chaîne TV/HDMI/source (MediaTek, Realtek, MStar, Amlogic, launchers stock...).
MOTS='tv|input|hdmi|cec|source|tvcenter|livetv|channel|mediatek|mtk|realtek|rtk|mstar|amlogic|droidlogic|launcher|keyevent|keyhandler|globalkey|tvsettings|inputs'

raison() {
  local p="$1" d
  if printf '%s\n' "$GLOBAL" | grep -qx "$p"; then echo "reçoit les touches globales (Input/Source)"; return; fi
  d=$(s dumpsys package "$p")
  if printf '%s' "$d" | grep -q 'TV_INPUT_HARDWARE';               then echo "pilote les entrées HDMI/AV (TV_INPUT_HARDWARE)"; return; fi
  if printf '%s' "$d" | grep -q 'android.media.tv.TvInputService'; then echo "service d'entrée TV (TvInputService)"; return; fi
  if printf '%s' "$d" | grep -q 'android.intent.category.HOME';    then echo "launcher d'origine (gère souvent la touche Input)"; return; fi
  if printf '%s' "$d" | grep -q -E 'vnd.android.cursor.(item|dir)/(channel|program)'; then echo "ouvre les chaînes/entrées TV"; return; fi
  if printf '%s' "$p" | grep -q -i -E "$MOTS";                      then echo "nom lié à la TV/aux entrées"; return; fi
}

remettre() {
  local p="$1" etat="$2" r
  if [ "$etat" = desactive ]; then r=$(s pm enable --user 0 "$p")
  else r=$(s cmd package install-existing --user 0 "$p"); case "$r" in *[Ee]xception*|*[Ee]rror*|*nknown*) r=$(s pm install-existing --user 0 "$p");; esac
  fi
  echo "   -> $r"
}

N=0
for etat in desactive desinstalle; do
  [ "$etat" = desactive ] && LISTE="$DESACTIVES" || LISTE="$DESINSTALLES"
  for p in $LISTE; do
    if [ "$TOUT" = "--tout" ]; then why="remise à l'état d'origine"; else why=$(raison "$p"); fi
    [ -n "$why" ] || continue
    N=$((N+1))
    if demande "[$etat] $p — $why. Le remettre ?"; then remettre "$p" "$etat"; fi
  done
done
[ "$N" -gt 0 ] || echo "Aucun paquet lié aux entrées n'est désactivé/désinstallé. Relance avec --tout pour tout remettre."

if [ "$(s settings get global hdmi_control_enabled)" = "0" ] && demande "HDMI-CEC est coupé. Le rallumer ?"; then
  s settings put global hdmi_control_enabled 1
fi

echo
echo "Attends 15 s (Android enregistre l'état des paquets avec un délai), puis redémarre :"
echo "  sleep 15; adb -s $TV shell sync; adb -s $TV reboot"
echo "Après le redémarrage, teste la VRAIE touche Input de la télécommande, depuis le launcher d'origine puis depuis Monet."
