# Télé Qilive (Android TV) : réparer la touche HDMI/Source, couper la LED, puis debloat

Tout se lance **depuis un ordi sur le même Wi-Fi que la télé** (Mac, Linux, ou Windows avec Git Bash/WSL),
avec `adb` installé ([Android platform-tools](https://developer.android.com/tools/releases/platform-tools)).

## 0. Préparer la télé

1. Paramètres > Préférences de l'appareil > À propos > appuie 7 fois sur **Build**.
2. Retour > **Options pour les développeurs** > active **Débogage USB** (et **Débogage réseau/ADB** si la télé l'a).
3. Note l'IP de la télé (Paramètres > Réseau), par ex. `192.168.1.42`.
4. Au premier lancement d'un script, accepte la fenêtre « Autoriser le débogage USB ? » sur la télé
   (coche « Toujours autoriser »).

```sh
cd qilive
chmod +x *.sh
```

## 1. Diagnostic (ne change rien)

```sh
./diagnostic.sh 192.168.1.42
```

Il affiche ce que le premier debloat a désactivé **ou désinstallé**, et surtout **à quelle appli Android
envoie la touche Input/Source**. C'est presque toujours la cause :

- La touche Source n'est pas gérée par le launcher (Monet ou autre). Android l'envoie à une appli précise du
  système : le launcher d'origine, l'appli TV du fabricant (`com.mediatek.wwtv.tvcenter`, `com.realtek...`,
  `...tvsettings`, etc.) ou un service de touches. Si le premier debloat a désactivé ou désinstallé cette appli,
  la touche ne fait plus rien, **même sous Monet**.
- Même chose si un paquet qui pilote les entrées (permission `TV_INPUT_HARDWARE`) a sauté : la télé voit le
  câble mais l'entrée reste noire ou introuvable.

## 2. Réparer la touche HDMI/Source

```sh
./reparer-hdmi.sh 192.168.1.42
```

Le script parcourt les paquets désactivés/désinstallés, ne garde que ceux liés aux entrées
(touches globales, `TV_INPUT_HARDWARE`, `TvInputService`, launcher d'origine, noms en tv/hdmi/input...)
et te demande **un par un** s'il faut les remettre. Il propose aussi de rallumer le HDMI-CEC.

Ensuite : attendre 15 s, `adb shell sync`, redémarrer, et tester avec la **vraie** télécommande
(une touche injectée par ADB ne prouve rien).

Si ça ne marche toujours pas, tout remettre comme à l'origine puis refaire le debloat proprement à l'étape 4 :

```sh
./reparer-hdmi.sh 192.168.1.42 --tout
```

> Si c'est le **launcher d'origine** qui gérait la touche Source : laisse-le **activé** et mets Monet en Home
> par défaut sans désactiver l'autre :
> `adb shell cmd package set-home-activity <paquet.monet>/<Activité>` (le nom exact est dans `home.txt` du diagnostic).

## 3. LED blanche de veille

```sh
./led.sh 192.168.1.42
```

Il cherche un réglage Android qui pilote le voyant et affiche la commande pour le couper **et celle pour
annuler** (il n'écrit rien lui-même). Sur beaucoup de télés d'entrée de gamme la LED de veille est câblée sur
le micro-contrôleur de veille et **aucun réglage logiciel ne l'éteint** : regarde d'abord dans
Paramètres > Préférences de l'appareil > Alimentation/Énergie (« Voyant de veille », « Indicateur
d'alimentation »). À défaut, un autocollant atténuateur de LED (type LightDims) ou un petit bout de gaffer noir
règle le problème à coup sûr.

## 4. Le vrai debloat avec cleanyourtv

[cleanyourtv](https://github.com/Gathin23/cleanyourtv) est fait pour être piloté par un assistant de code
(Claude Code, etc.) **lancé sur ton ordi**, sur le même Wi-Fi que la télé : il faut qu'il puisse parler à la
télé en ADB, ce qu'une session cloud ne peut pas faire.

```sh
git clone https://github.com/Gathin23/cleanyourtv
cd cleanyourtv
python3 -m venv tools/venv && tools/venv/bin/pip install -r tools/requirements.txt
```

Puis ouvre Claude Code dans ce dossier et colle le contenu de `PROMPT.md` en remplaçant
`<MODEL NAME HERE>` par le modèle exact (affiché en haut de `diagnostic.sh`). Précise-lui aussi :

- « Le repo est cloné, réutilise `tools/` et `launcher/`. »
- « Un premier debloat a déjà été fait à la main ; voici le dossier `diagnostic-...` : ne re-désactive pas
  les paquets que `reparer-hdmi.sh` a remis. »
- « Garde la touche Input/Source fonctionnelle : teste-la avec la vraie télécommande après chaque lot. »

Points de sécurité utiles pour une Qilive (aucune fiche Qilive dans le repo pour l'instant) :

- Passe par `tools/disable.sh` (jamais `pm uninstall`) : il refuse les paquets système critiques et
  **saute ceux qui pilotent les entrées HDMI** (`TV_INPUT_HARDWARE`), exactement ce qui a dû casser la première fois.
  `tools/restore.sh` défait ensuite tout.
- Petits lots, capture d'écran entre chaque, 15 s d'attente avant de redémarrer.
- N'ouvre **jamais** une appli dont le nom contient `factory`, `fac`, `production` ou `at` (menu usine) :
  sur certaines cartes ça tue la touche Input et le CEC.
- Si tu prends leur launcher au lieu de Monet : il a un bouton « Inputs » qui liste les HDMI, et un service
  optionnel `InputKeyService` qui fait marcher la touche Source même avec le launcher d'origine désactivé.
- À la fin, coupe le débogage réseau/USB.

Si ça marche bien, ils acceptent les listes testées : un `examples/qilive-<modèle>/debloat.txt` aiderait les
prochains propriétaires de Qilive.
