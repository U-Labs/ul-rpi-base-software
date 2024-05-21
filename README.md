# <img src="https://u-img.net/img/5176Ur.png" style="vertical-align: middle" /> U-Labs Raspberry Pi Basis-Software
Installiert nützliche GNU/Linux-Werkzeuge, die ich auf [U-Labs](https://u-labs.de/portal/) vorgestellt habe, mit wenigen Handgriffen auf dem Raspberry Pi.

## Verwendung
```bash
wget https://raw.githubusercontent.com/U-Labs/ul-rpi-base-software/main/ul-rpi-base-software.sh
bash ul-rpi-base-software.sh
```
Navigiert wird über die Pfeiltasten hoch/runter, oder alternativ die Nummern (mit "7" springt man z.B. direkt zu Docker). Leertaste wählt einen EIntrag aus/ab. Mit Tab gelangt man zu den zwei Knöpfen unten, um mit _OK_ die Installation der ausgewählten Software zu starten. _Abbrechen_ beendet das Skript.

## Entwicklung
Für die Dialoge wird [`whiptail`](https://gijs-de-jong.nl/posts/pretty-dialog-boxes-for-your-shell-scripts-using-whiptail/#checklist-box) verwendet. Es ist [eine leichtgewichtigere Alternative zu `dialog`](https://unix.stackexchange.com/a/64630/214989) und in vielen auf Debian basierten Systemen vorinstalliert, wie u.a. dem Raspberry Pi OS. Zwar bietet `dialog` [weitere Funktionen](https://www.dev-insider.de/dialogboxen-mit-whiptail-erstellen-a-860990/), die jedoch nicht benötigt werden, sodass diese zusätzliche Abhängigkeit verzichtbar ist.