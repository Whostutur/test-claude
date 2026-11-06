#!/usr/bin/env bash
# Cherche comment couper la LED blanche de veille. LECTURE SEULE : le script n'écrit rien,
# il affiche les réglages candidats avec la commande pour les changer ET celle pour annuler.
#
# Usage : ./led.sh <ip-de-la-tele>
set -u
TV="${1:?usage: ./led.sh <ip-de-la-tele>}"
case "$TV" in *:*) ;; *) TV="$TV:5555" ;; esac
adb connect "$TV" >/dev/null 2>&1
adb -s "$TV" get-state >/dev/null 2>&1 || { echo "Pas de connexion ADB à $TV." >&2; exit 1; }
s() { adb -s "$TV" shell "$@" </dev/null 2>&1 | tr -d '\r'; }

MOTIF='(^|[_.[])(led|leds|indicator|standby_?light|power_?light|breath|lamp)([]_.=]|$)'
EXCLURE='^$'
trouve=0
for ns in system secure global; do
  while IFS= read -r ligne; do
    [ -n "$ligne" ] || continue
    trouve=1
    cle="${ligne%%=*}"; val="${ligne#*=}"
    case "$val" in 1|true|on) nouv=0 ;; 0|false|off) nouv="(déjà à $val)" ;; *) nouv="?" ;; esac
    echo "[$ns] $cle = $val"
    if [ "$nouv" = 0 ]; then
      echo "   couper  : adb -s $TV shell settings put $ns $cle 0"
      echo "   annuler : adb -s $TV shell settings put $ns $cle $val"
    fi
  done < <(s settings list "$ns" | grep -i -E "$MOTIF" | grep -v -i -E "$EXCLURE")
done

echo
echo "Propriétés système :"
s getprop | grep -i -E "$MOTIF" | grep -v -i -E "$EXCLURE" || echo "  (aucune)"
echo
echo "LED pilotées par le noyau (/sys/class/leds) :"
s 'for d in /sys/class/leds/*; do [ -e "$d" ] && echo "  $d  brightness=$(cat $d/brightness 2>&1)  trigger=$(cat $d/trigger 2>&1 | tr -d "\n" | cut -c1-80)"; done' \
  | grep . || echo "  (aucune ou illisible sans root)"
echo
echo "Activités de réglages qui parlent de LED/voyant/veille :"
s dumpsys package | grep -i -o -E '[a-zA-Z0-9_.]+/[a-zA-Z0-9_.$]*(Led|LED|Indicator|Standby|PowerLight)[a-zA-Z0-9_.$]*' | sort -u | head -20 \
  || echo "  (aucune)"

echo
if [ "$trouve" = 0 ]; then
  echo "Aucun réglage Android ne pilote la LED : sur ce modèle elle est sans doute gérée par le micro-contrôleur"
  echo "de veille. Regarde quand même dans Paramètres > Préférences de l'appareil > Alimentation (ou Énergie /"
  echo "Système) une option « Voyant de veille », « Indicateur d'alimentation » ou « LED »."
  echo "Sinon : un autocollant atténuateur de LED (type LightDims) ou un bout de scotch noir/gaffer."
fi
