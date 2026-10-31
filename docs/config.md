# Belegung (config.toml)

Diese Datei beschreibt das Format der Belegung verbindlich. Ändert sich das Format, wird zuerst diese Datei angepasst, dann `app/Resources/default-config.toml` und der CHANGELOG.

Die Datei liegt an zwei Orten:

- **App:** `~/Library/Application Support/NuimoBar/config.toml`. Das Menü öffnet sie über „Belegung bearbeiten …“.
- **Python-Bridge:** `config.toml` neben `bridge.py`.

Änderungen gelten sofort, ohne Neustart. Enthält die Datei einen Syntaxfehler, bleibt die vorige Belegung aktiv. Die App zeigt den Fehler im Menü, `bridge.py` gibt ihn im Terminal aus.

Einige Angaben versteht nur die App, siehe [Unterschiede zu bridge.py](#unterschiede-zu-bridgepy).

## Aufbau

```toml
[settings]           # Einstellungen
[default]            # Standardprofil
[apps.TradingView]   # Profil für eine App
[modes.Resolume]     # Modus, nur App
```

Jedes Profil ordnet Ereignissen Aktionen zu: `ereignis = "aktion"`.

**Apps** werden über ihren Namen, wie er im Dock steht, oder über ihre Bundle-ID erkannt. Namen mit Leerzeichen stehen in Anführungszeichen: `[apps."Google Chrome"]`, `[apps."Resolume Arena"]`.

**Modi** gelten unabhängig von der App, die vorne ist. Sie werden im Menü oder per Aktion `mode:` eingeschaltet. Es ist höchstens ein Modus gleichzeitig aktiv.

### Reihenfolge der Auflösung

Für jedes Ereignis werden die Profile in dieser Reihenfolge durchsucht:

1. aktiver Modus, falls einer eingeschaltet ist
2. Profil der App, die vorne ist
3. `[default]`

Das erste Profil, das das Ereignis enthält, entscheidet. Mit `none` lässt sich ein Ereignis bewusst stilllegen, dann werden die folgenden Profile nicht mehr gefragt.

Beim Drehen entscheidet das erste Profil, das entweder `rotate` oder `rotate_left`/`rotate_right` enthält. Für `rotate_pressed` gilt das entsprechend.

## Einstellungen

| Schlüssel | Standard | Bedeutung |
|---|---|---|
| `scroll_speed` | `0.5` | Pixel pro Drehwert bei `scroll`. Ein negativer Wert kehrt die Richtung um. |
| `rotate_step` | `300` | Drehwert pro Schritt bei `rotate_left`/`rotate_right`. Eine volle Umdrehung ergibt etwa 2650. |
| `midi_channel` | `1` | MIDI-Kanal 1–16, wenn eine Aktion keinen eigenen angibt. Nur App. |
| `midi_cc_per_turn` | `127` | Änderung eines CC-Werts pro voller Umdrehung. Nur App. |
| `midi_relative` | `"twos"` | Kodierung für relative CCs: `"twos"` (1 = +1, 127 = −1) oder `"offset"` (65 = +1, 63 = −1). Nur App. |

## Ereignisse

### Taste

| Ereignis | Auslöser |
|---|---|
| `press` | kurzer Druck. Wird erst nach 0,35 s gemeldet, weil ein zweiter Druck folgen könnte. |
| `double_press` | zwei kurze Drücke innerhalb von 0,35 s |
| `long_press` | Taste 0,4 s gehalten |
| `hold` | Drücken und Loslassen getrennt, ohne Verzögerung. Ist `hold` belegt, sind `press`, `double_press` und `long_press` abgeschaltet. Nur App. |

Wird während des Drückens gedreht, zählt der Druck nicht als `press` und nicht als `long_press`.

### Wischen, Tippen, Hand

| Ereignis | Auslöser |
|---|---|
| `swipe_left`, `swipe_right`, `swipe_up`, `swipe_down` | Wischen über die Oberfläche. Kommt nur an, wenn man ganz bis zum Rand wischt. |
| `touch_left`, `touch_right`, `touch_top`, `touch_bottom` | kurzes Tippen an den Rand |
| `longtouch_left`, `longtouch_right`, `longtouch_top`, `longtouch_bottom` | langes Berühren am Rand |
| `fly_left`, `fly_right` | Hand über dem Nuimo nach links oder rechts bewegen |

### Drehen

| Ereignis | Auslöser |
|---|---|
| `rotate` | Drehen, fortlaufend. Erlaubt: `volume`, `scroll`, `midi:cc`. |
| `rotate_pressed` | Drehen bei gedrückter Taste, fortlaufend. Erlaubt wie bei `rotate`. |
| `rotate_left`, `rotate_right` | Drehen in Schritten von `rotate_step`. Erlaubt sind alle Aktionen für Auslöser. |
| `rotate_pressed_left`, `rotate_pressed_right` | wie oben, bei gedrückter Taste |

## Aktionen

### Für Auslöser

Auslöser sind alle Ereignisse außer `rotate`, `rotate_pressed` und `hold`.

| Aktion | Wirkung |
|---|---|
| `keys:<kürzel>` | Tastenkürzel, z. B. `keys:opt+return`, `keys:cmd+shift+4`. Siehe [Tasten](#tasten). |
| `media:<taste>` | Medientaste: `playpause`, `next`, `previous`, `mute` |
| `shell:<befehl>` | Shell-Befehl, z. B. `shell:shortcuts run 'Licht an'`. Die App nutzt `/bin/zsh -lc`, die Bridge `/bin/sh`. |
| `midi:note:<nr>` | Note On (Velocity 127), nach 50 ms Note Off. `nr` 0–127. Nur App. |
| `midi:cc:<nr>` | CC-Wert 127, nach 50 ms 0. Nur App. |
| `midi:cc:<nr>=<wert>` | CC mit festem Wert 0–127. Nur App. |
| `midi:pc:<nr>` | Program Change 0–127. Nur App. |
| `mode:<Name>` | Modus einschalten. Nur App. |
| `mode:off` | Modus ausschalten. Nur App. |
| `mode:toggle:<Name>` | Modus ein- oder ausschalten. Nur App. |
| `none` | nichts tun, auch nicht das, was in einem folgenden Profil steht |

### Für Drehen (`rotate`, `rotate_pressed`)

| Aktion | Wirkung |
|---|---|
| `volume` | Systemlautstärke, mit Pegel auf der Matrix |
| `scroll` | Mausrad an der Position des Mauszeigers. Mit Tasten: `scroll:ctrl+opt`. |
| `midi:cc:<nr>` | Absoluter CC-Wert 0–127, mit Pegel auf der Matrix. Die App merkt sich den Wert pro Kanal und Controller, solange sie läuft. Er beginnt bei 0. Nur App. |
| `midi:cc:<nr>:relative` | Relative Änderung, kodiert nach `midi_relative`. Nur App. |
| `none` | nichts tun |

### Für `hold`

| Aktion | Wirkung |
|---|---|
| `midi:note:<nr>` | Note On beim Drücken, Note Off beim Loslassen |
| `midi:cc:<nr>` | Wert 127 beim Drücken, 0 beim Loslassen |
| `none` | `hold` stilllegen; dann gelten wieder `press`, `double_press` und `long_press` |

### MIDI-Kanal

Jede MIDI-Aktion kann am Ende mit `@<kanal>` einen eigenen Kanal 1–16 bekommen, z. B. `midi:note:36@10` oder `midi:cc:21:relative@2`. Ohne Angabe gilt `midi_channel`.

Die App stellt dafür einen virtuellen MIDI-Ausgang mit dem Namen „Nuimo“ bereit. In Resolume wird er unter Preferences › MIDI als Eingang aktiviert.

### Tasten

Ein Kürzel besteht aus null oder mehr Modifiern und genau einer Taste, verbunden mit `+`.

- Modifier: `cmd`, `shift`, `ctrl`, `opt` (auch `alt`).
- Buchstaben und Ziffern: `a`–`z`, `0`–`9`.
- Zeichen: `-`, `=`, `[`, `]`, `\`, `;`, `'`, `,`, `.`, `/`, `` ` ``.
- Sondertasten: `return`, `enter`, `tab`, `space`, `delete`, `forwarddelete`, `escape`, `home`, `end`, `pageup`, `pagedown`, `left`, `right`, `up`, `down`.
- Funktionstasten: `f1`–`f20`.

Tasten folgen der Position auf der US-Tastatur. Auf einer deutschen Tastatur sind deshalb `y` und `z` vertauscht, und Zeichen wie `-` oder `/` liegen auf anderen Tasten als aufgedruckt.

## Rückmeldung auf der Matrix

| Was | Bild |
|---|---|
| `press`, `long_press`, `double_press` | Smiley, gefüllter Kreis, zwei Punkte |
| Wischen, `fly_*` | Pfeil in die jeweilige Richtung |
| Tippen, langes Berühren | Punkt am jeweiligen Rand |
| `volume`, absoluter `midi:cc` | Pegel |
| Modus an / aus | „M“ / „X“, nur App |

Ein Bild erscheint nur, wenn eine Aktion ausgeführt wurde, nicht bei `none` oder unbelegten Ereignissen.

## Beispiele

### Standard und TradingView

```toml
[settings]
scroll_speed = 0.5
rotate_step = 300

[default]
rotate = "volume"
press = "media:playpause"
double_press = "media:mute"
swipe_left = "media:previous"
swipe_right = "media:next"

[apps.TradingView]
rotate = "scroll"
press = "keys:opt+return"      # aktives Chart maximieren / zurück
swipe_right = "keys:tab"       # nächstes Chart
swipe_left = "keys:shift+tab"  # voriges Chart
```

### Resolume als Modus

Der Modus wird mit langem Berühren oben ein- und ausgeschaltet und gilt dann auch, wenn eine andere App vorne ist.

```toml
[settings]
midi_channel = 1
midi_cc_per_turn = 127
midi_relative = "twos"

[default]
longtouch_top = "mode:toggle:Resolume"

[modes.Resolume]
rotate = "midi:cc:20"                  # z. B. Opacity der Ebene
rotate_pressed = "midi:cc:21:relative" # z. B. Effektstärke, in Resolume auf „Relative“ stellen
hold = "midi:note:40"                  # Flash, solange gedrückt
swipe_right = "midi:note:36"           # nächster Clip
swipe_left = "midi:note:37"            # voriger Clip
fly_left = "midi:pc:0"                 # Komposition 1
fly_right = "midi:pc:1"                # Komposition 2
longtouch_top = "mode:toggle:Resolume"
```

Weil `hold` belegt ist, gibt es in diesem Modus keinen `press`, `double_press` oder `long_press`.

### Resolume nur, wenn es vorne ist

```toml
[apps."Resolume Arena"]
rotate = "midi:cc:20"
press = "midi:note:36@2"
```

## Unterschiede zu bridge.py

Die Python-Bridge ist ein Prototyp und kennt nur einen Teil des Formats:

| Angabe | App | bridge.py |
|---|---|---|
| `[settings]`, `[default]`, `[apps.*]` | ja | ja |
| `keys`, `media`, `volume`, `scroll`, `shell`, `none` | ja | ja |
| `[modes.*]`, `mode:*` | ja | nein |
| `midi:*`, `midi_*`-Einstellungen | ja | nein |
| Ereignis `hold` | ja | nein |

Unbekannte Aktionen wie `midi:*` oder `mode:*` meldet `bridge.py` im Terminal und führt sie nicht aus. Abschnitte `[modes.*]`, die `midi_*`-Einstellungen und das Ereignis `hold` übergeht sie ohne Meldung.
