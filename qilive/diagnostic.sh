#!/usr/bin/env bash
# Diagnostic de la télé Qilive (Android TV) — LECTURE SEULE, ne modifie rien sur la télé.
#
# Usage : ./diagnostic.sh <ip-de-la-tele>
# Exemple : ./diagnostic.sh 192.168.1.42
#
# Écrit tout dans un dossier diagnostic-<date>/ et affiche un résumé :
#   - paquets désactivés et désinstallés (pour l'utilisateur 0) par le premier debloat
#   - à quelle appli Android envoie la touche Input/Source (les « global keys »)
#   - état des entrées HDMI (tv_input) et du HDMI-CEC
#   - réglages qui ressemblent à la LED de veille
set -u
TV="${1:?usage: ./diagnostic.sh <ip-de-la-tele>}"
case "$TV" in *:*) ;; *) TV="$TV:5555" ;; esac
command -v adb >/dev/null || { echo "adb introuvable : installe Android platform-tools d'abord." >&2; exit 1; }

adb connect "$TV" >/dev/null 2>&1
if ! adb -s "$TV" get-state >/dev/null 2>&1; then
  echo "Pas de connexion ADB à $TV." >&2
  echo "Sur la télé : Options pour les développeurs > Débogage USB (et Débogage réseau/ADB s'il existe)," >&2
  echo "puis accepte la fenêtre « Autoriser le débogage ? » qui s'affiche, et relance." >&2
  exit 1
fi
s() { adb -s "$TV" shell "$@" </dev/null 2>&1 | tr -d '\r'; }

OUT="diagnostic-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
echo "Collecte dans $OUT/ ..."

s getprop                                 > "$OUT/getprop.txt"
s pm list packages -f                     > "$OUT/paquets-tous.txt"
s pm list packages -d | sed 's/^package://' | sort > "$OUT/paquets-desactives.txt"
s pm list packages -u | sed 's/^package://' | sort > "$OUT/_u.txt"
s pm list packages    | sed 's/^package://' | sort > "$OUT/_i.txt"
comm -23 "$OUT/_u.txt" "$OUT/_i.txt"      > "$OUT/paquets-desinstalles-user0.txt"
rm -f "$OUT/_u.txt" "$OUT/_i.txt"
for ns in system secure global; do s settings list "$ns" > "$OUT/settings-$ns.txt"; done
s dumpsys window                          > "$OUT/dumpsys-window.txt"
s dumpsys window policy                   > "$OUT/dumpsys-window-policy.txt"
s dumpsys tv_input                        > "$OUT/dumpsys-tv_input.txt"
s dumpsys hdmi_control                    > "$OUT/dumpsys-hdmi_control.txt"
s cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.HOME > "$OUT/home.txt"
s cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME > "$OUT/home-actuel.txt"
s 'ls -l /sys/class/leds/ 2>&1; for f in /sys/class/leds/*/brightness /sys/class/leds/*/trigger; do echo "$f: $(cat $f 2>&1)"; done' > "$OUT/sys-leds.txt"

prop() { grep -F "[$1]" "$OUT/getprop.txt" | sed -E 's/.*\]: \[(.*)\]/\1/'; }
echo
echo "=== Télé ==="
echo "Modèle   : $(prop ro.product.manufacturer) $(prop ro.product.model) ($(prop ro.product.device))"
echo "Android  : $(prop ro.build.version.release) (SDK $(prop ro.build.version.sdk)), build $(prop ro.build.display.id)"
echo "Puce     : $(prop ro.board.platform) $(prop ro.hardware)"

echo
echo "=== Paquets désactivés ($(wc -l < "$OUT/paquets-desactives.txt")) ==="
cat "$OUT/paquets-desactives.txt"
echo
echo "=== Paquets désinstallés pour l'utilisateur 0 ($(wc -l < "$OUT/paquets-desinstalles-user0.txt")) ==="
cat "$OUT/paquets-desinstalles-user0.txt"

echo
echo "=== Où va la touche Input/Source (global keys) ==="
grep -i -A40 -E 'mKeyMapping|GlobalKey' "$OUT/dumpsys-window.txt" "$OUT/dumpsys-window-policy.txt" \
  | grep -i -E 'TV_INPUT|KEYCODE_TV|ComponentInfo|keycode' | head -30 \
  || echo "(rien trouvé — la touche est peut-être gérée par l'appli TV du fabricant)"

echo
echo "=== Launcher (Home) actuel ==="
grep -m1 -E 'name=|packageName=' "$OUT/home-actuel.txt" || head -5 "$OUT/home-actuel.txt"

echo
echo "=== HDMI-CEC ==="
grep -E '^hdmi_control_enabled=' "$OUT/settings-global.txt" || echo "hdmi_control_enabled non défini"
echo "Entrées TV déclarées : $(grep -c -E 'TvInputInfo|inputId' "$OUT/dumpsys-tv_input.txt")"

echo
echo "=== Réglages qui ressemblent à la LED de veille ==="
grep -i -h -E '(^|[_.[])(led|leds|indicator|standby_?light|power_?light|breath|lamp)([]_.=]|$)' \
  "$OUT"/settings-*.txt "$OUT/getprop.txt" || echo "(aucun)"
echo "LED dans /sys/class/leds :"; sed 's/^/  /' "$OUT/sys-leds.txt"

echo
echo "Tout est dans $OUT/ — envoie ce dossier (ou ce résumé) si tu veux qu'on regarde ensemble."
