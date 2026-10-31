# Spec 001: Menüleisten-App

Status: In Arbeit · Stand: 2026-10-31

## 1. Ziel und Rahmen

Der Nuimo soll den Mac ohne Terminal steuern. Dafür entsteht eine native macOS-App in Swift, die in der Menüleiste sitzt, Verbindung und Akku anzeigt, beim Login startet und sich weitergeben lässt.

Die App übernimmt Logik und Belegungsformat von `bridge.py` und erweitert sie um MIDI, damit der Nuimo auch Resolume steuern kann.

In v1 enthalten:

- Alles, was `bridge.py` heute kann, mit demselben Format der Belegung.
- MIDI-Ausgang für CC, Notes, gehaltene Notes und Program Change.
- Modi, die vor allen App-Profilen gelten und sich per Menü oder Geste schalten lassen.
- Menü mit Status, aktivem Profil, letzter Geste, Login-Start und Debug-Log.

Nicht in v1:

- Grafischer Editor für die Belegung. Er kommt erst, wenn ein konkreter Anwendungsfall feststeht.
- Schalter zum Pausieren. Wer mit den Python-Skripten testen will, beendet die App.
- Weitergabe ohne Gatekeeper-Warnung (Developer ID und Notarisierung).
- MIDI-Rückkanal von Resolume.

Die Python-Skripte bleiben im Projekt. Mit ihnen werden neue Ideen am Gerät ausprobiert, bevor sie in eine Spec und in die App wandern.

## 2. Entscheidungen

| Entscheidung | Begründung |
|---|---|
| Swift mit SwiftUI statt Python als App-Bundle | Native APIs für Bluetooth, Tastatur-Events und MIDI. Kleine App, schneller Start, Berechtigungen für Bluetooth und Bedienungshilfen funktionieren zuverlässig. Ein gebündelter Python-Interpreter wäre groß und bei Berechtigungen unzuverlässig. |
| SwiftPM statt Xcode-Projekt | Baut vollständig auf der Kommandozeile, Projektdateien sind lesbar und gut zu versionieren. Das Paket lässt sich trotzdem in Xcode öffnen. |
| Belegung als TOML mit TOMLKit | Das Format von `config.toml` bleibt erhalten. Bestehende Belegungen funktionieren weiter. |
| Lautstärke über CoreAudio statt `osascript` | Kein Prozessstart pro Drehung, der aktuelle Wert lässt sich bei jeder Drehung frisch lesen. |
| Ausstehendes `connect()` statt Such-Schleife | CoreBluetooth hält einen Verbindungswunsch ohne Timeout offen und verbindet, sobald der Nuimo aufwacht. Das spart Energie und Code. |
| Keine App-Sandbox | Tastatur- und Scroll-Events an andere Apps funktionieren in der Sandbox nicht zuverlässig. |
| Signatur mit „Apple Development“ | Das Zertifikat ist vorhanden. Eine stabile Signatur sorgt dafür, dass die Freigabe für Bedienungshilfen einen Neubau übersteht. Developer ID folgt bei Bedarf. |

## 3. Aufbau

```
nuimo/
  bridge.py, nuimo.py, config.toml    Python-Prototyp
  docs/                                Specs und Referenz der Belegung
  app/
    Package.swift                      SwiftPM, macOS 14+, Abhängigkeit TOMLKit
    .swift-format
    build.sh                           baut, bündelt, signiert; „install“ kopiert nach /Applications
    Resources/
      Info.plist
      default-config.toml
    Sources/NuimoBar/
      NuimoBarApp.swift                @main, MenuBarExtra, Symbol in der Menüleiste
      MenuContent.swift                Menüinhalt
      AppModel.swift                   setzt die Teile beim Start zusammen
      AppState.swift                   beobachtbarer Zustand für das Menü
      ConnectionStatus.swift           Verbindungszustand und Statuszeile
      NuimoDevice.swift                CoreBluetooth: Suche, Verbindung, Notifications, Akku
      NuimoProtocol.swift              UUIDs, Dekodierung der Sensordaten
      Gesture.swift                    Auslöser-Ereignisse und ihr Bild auf der Matrix
      MatrixImage.swift                Muster, Pegel, Bytes
      MatrixDisplay.swift              Display-Warteschlange
      ButtonGestures.swift             kurzer, langer, doppelter Druck, hold
      Scheduler.swift                  Zeitgeber als Protokoll, damit Tests ohne Warten auskommen
      MainScheduler.swift              Zeitgeber mit echter Zeit
      Config.swift                     TOML laden, neu laden, Profile auflösen
      Controller.swift                 Ereignis → Profil → Aktion
      Actions.swift                    Tasten, Medientasten, Scrollen, Shell
      Volume.swift                     Systemlautstärke über CoreAudio
      MIDIOut.swift                    virtueller MIDI-Ausgang
      DebugLog.swift                   abschaltbares Log in eine Datei
    Tests/NuimoBarTests/
```

`Info.plist`:

- `LSUIElement` = true: kein Dock-Symbol.
- `NSBluetoothAlwaysUsageDescription`: Begründung für die Bluetooth-Abfrage.
- Bundle-ID `com.siedler.NuimoBar`, Version 0.1.0.

Pfade zur Laufzeit:

- Belegung: `~/Library/Application Support/NuimoBar/config.toml`. Beim ersten Start wird dort `default-config.toml` angelegt.
- Debug-Log: `~/Library/Logs/NuimoBar/debug.log`.
- Einstellungen der App (Debug-Log, aktiver Modus, Nuimo-Identifier, MIDI-ID): `UserDefaults`.

## 4. Übernahme der vorhandenen Logik

Verhalten und Konstanten bleiben gleich. Vorlage ist jeweils der Python-Code.

- **Protokoll** (`nuimo.py`, Konstanten oben):
  - Sensor-Characteristics `f29b1526` bis `f29b1529` mit dem Suffix `-cb19-40f3-be5c-7241ecb82fd2` (Fly, Swipe, Rotation, Taste).
  - Matrix `f29b1524-cb19-40f3-be5c-7241ecb82fd1`, Akku `2a19`.
  - Drehwert als Int16 little-endian, Taste `data[0]` mit 1 = gedrückt und 0 = losgelassen.
  - Swipe-Codes 0–11 in der Reihenfolge von `SWIPE_EVENTS` in `bridge.py`, Fly-Codes 0 = links und 1 = rechts.
- **Matrix** (`nuimo.py`: `grid`, `rotate`, Muster, `level`, `matrix_bytes`, `Display`):
  - 11 Bytes Pixel-Bits, dann Helligkeit, dann Anzeigedauer in 1/10 s.
  - Kommen Bilder schneller, als BLE sie schreibt, gewinnt das neueste. Geschrieben wird mit Response, das nächste Bild erst nach `didWriteValueFor`.
  - Das erste Bild erst 2 s nach dem Verbinden schicken, sonst überschreibt die Haken-Animation des Nuimo es.
- **Gesten** (`nuimo.py`: `ButtonGestures`):
  - Langer Druck nach 0,4 s, Wartezeit auf einen zweiten Druck 0,35 s.
  - Wird während des Drückens gedreht, zählt der Druck nicht als Klick.
- **Belegung** (`bridge.py`: `Config`, `session.profiles`, `on_event`, `on_rotate`):
  - Profil nach App-Name oder Bundle-ID, sonst `[default]`. `none` beendet den Fallback.
  - `rotate` und `rotate_pressed` fortlaufend oder schrittweise über `_left`/`_right` mit Rest pro Basis.
  - Die Datei wird neu geladen, wenn sich ihr Änderungsdatum geändert hat. Geprüft wird bei jedem Ereignis. Bei einem Syntaxfehler bleibt die alte Belegung aktiv.
- **Aktionen** (`bridge.py`: `KEYCODES`, `MODIFIERS`, `MEDIA_KEYS`, `send_keys`, `send_scroll`, `send_media`):
  - Tasten per `CGEvent` an `.cghidEventTap`.
  - Medientasten per `NSEvent.otherEvent` vom Typ `.systemDefined`, Subtyp 8.
  - Scrollen per Scroll-Event in Pixeln.
  - `shell:` läuft über `/bin/zsh -lc`, damit Pfade wie die von Homebrew gelten.
- **Lautstärke** (`bridge.py`: `Volume`): `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` des Standard-Ausgabegeräts.
  - Der Wert wird bei jeder Drehung frisch gelesen. Damit entfällt das Neueinlesen nach 2 s.
  - Geräte ohne Lautstärkeregler, z. B. HDMI, werden im Log gemeldet.

## 5. MIDI

### Ausgang

Die App legt per CoreMIDI eine virtuelle Quelle mit dem Namen „Nuimo“ an (`MIDISourceCreateWithProtocol`, MIDI 1.0). Resolume und andere Programme sehen sie als MIDI-Eingang.

Die `kMIDIPropertyUniqueID` wird beim ersten Start erzeugt und gespeichert. So erkennt Resolume seine Zuordnungen nach einem Neustart der App wieder.

### Aktionen

Kurzfassung, die vollständige Beschreibung steht in [docs/config.md](../config.md):

| Aktion | Wirkung |
|---|---|
| `midi:note:<nr>` | Auslöser: Note On mit Velocity 127, Note Off nach 50 ms. Bei `hold`: Note On beim Drücken, Note Off beim Loslassen. |
| `midi:cc:<nr>` | Bei `rotate`/`rotate_pressed`: absoluter Wert 0–127, den die App pro Kanal und Controller mitführt. Bei `hold`: 127 beim Drücken, 0 beim Loslassen. Sonst: 127, nach 50 ms 0. |
| `midi:cc:<nr>:relative` | Nur bei `rotate`/`rotate_pressed`: relative Änderung, Kodierung nach `midi_relative`. |
| `midi:cc:<nr>=<wert>` | Auslöser: sendet einen festen Wert 0–127. |
| `midi:pc:<nr>` | Auslöser: Program Change 0–127. |

Jede MIDI-Aktion kann mit `@<kanal>` (1–16) einen eigenen Kanal bekommen, sonst gilt `midi_channel`.

Neue Einstellungen: `midi_channel` (Standard 1), `midi_cc_per_turn` (Standard 127, Wertänderung pro voller Umdrehung) und `midi_relative` (Standard `"twos"`).

Für relative CCs gibt es zwei Kodierungen:

- `"twos"`: 1 = +1, 127 = −1.
- `"offset"`: 65 = +1, 63 = −1.

Welche davon Resolume im Modus „Relative“ erwartet, ist nicht dokumentiert und wird beim Handtest geklärt. Pro Nachricht werden höchstens ±63 Schritte gesendet.

Rückmeldung auf der Matrix:

- Absoluter CC: Pegel wie bei der Lautstärke.
- Notes, feste CC-Werte und Program Change: das Gestenbild wie bei anderen Aktionen.

### Ereignis `hold`

Ist `hold` für die aktive Belegung gesetzt (nicht `none`), wird die Taste direkt durchgereicht: Drücken und Loslassen lösen die Aktion jeweils sofort aus. Kurzer, langer und doppelter Druck sind dann abgeschaltet. Drehen bleibt nutzbar, auch `rotate_pressed`.

Welche Belegung gilt, entscheidet sich beim Drücken. Das Loslassen gehört immer zum selben Druck, auch wenn inzwischen eine andere App vorne ist.

Erlaubte Aktionen für `hold` sind `midi:note:<nr>` und `midi:cc:<nr>`.

### Modi

Abschnitte `[modes.<Name>]` beschreiben Belegungen, die sich unabhängig von der aktiven App einschalten lassen. Ist ein Modus aktiv, gilt die Reihenfolge Modus → App-Profil → `[default]`.

Umschalten:

- Im Menü über das Untermenü „Modus“ mit „Aus“ und allen Modi aus der Datei.
- Per Aktion: `mode:<Name>`, `mode:off` und `mode:toggle:<Name>`.

Beim Einschalten zeigt die Matrix kurz ein „M“, beim Ausschalten ein „X“:

```
Modus an     Modus aus
.........    .........
.*.....*.    .*.....*.
.**...**.    ..*...*..
.*.*.*.*.    ...*.*...
.*..*..*.    ....*....
.*.....*.    ...*.*...
.*.....*.    ..*...*..
.*.....*.    .*.....*.
.........    .........
```

Der aktive Modus bleibt über einen Neustart der App erhalten. Fehlt er nach dem Neuladen der Datei, gilt „Aus“.

## 6. Verbindung

- `CBCentralManager` auf der Main-Queue, die Anbindung läuft auf `@MainActor`.
- Beim ersten Mal wird nach einem Gerät mit dem Namen „Nuimo“ gesucht und dessen Identifier gespeichert.
- Danach `retrievePeripherals(withIdentifiers:)` und `connect()`. Der Verbindungswunsch bleibt offen, bis der Nuimo erreichbar ist. Nach einer Trennung wird er sofort neu gestellt.
- Wird der gespeicherte Nuimo nicht mehr gefunden, sucht die App wieder nach dem Namen.
- Akku beim Verbinden lesen. Unterstützt die Characteristic Notify, wird es abonniert, sonst wird alle 10 Minuten gelesen.
- Ist Bluetooth aus oder für die App nicht erlaubt, zeigt das Menü das an.

## 7. Menü

```
◉ Verbunden · Akku 82 %
  Profil: TradingView
  Letzte Geste: press → keys:opt+return
⚠ Bedienungshilfen freigeben …          (nur wenn nötig)
⚠ Fehler in config.toml: …              (nur wenn nötig)
───────────────
  Modus                  ▸  ✓ Aus
                              Resolume
  Belegung bearbeiten …
✓ Beim Login starten
  Debug-Log
  Log öffnen …
───────────────
  Beenden                                ⌘Q
```

- Das Symbol in der Menüleiste ist ein SF Symbol und unterscheidet verbunden und getrennt.
- Die Statuszeile zeigt je nach Lage „Verbunden · Akku 82 %“, „Suche Nuimo … (einmal drücken)“, „Bluetooth ist aus“ oder „Bluetooth nicht erlaubt“.
- Die Profilzeile zeigt „Profil: <App>“ oder „Profil: Standard“. Bei aktivem Modus zeigt sie „Modus: <Name>“.
- „Bedienungshilfen freigeben …“ fragt die Freigabe an und öffnet die passende Seite der Systemeinstellungen. Ohne Freigabe kommen Tasten, Medientasten und Scrollen nicht an, MIDI und Lautstärke funktionieren trotzdem.
- „Belegung bearbeiten …“ öffnet `config.toml` im Standard-Editor.
- „Beim Login starten“ nutzt `SMAppService.mainApp`.
- „Debug-Log“ schreibt Rohdaten, Gesten, Profilauflösung, Aktionen, MIDI-Bytes und Fehler in die Log-Datei. „Log öffnen …“ öffnet sie.

Texte im Menü sind deutsch und laufen über `String(localized:)`.

## 8. Testkonzept

### Unit-Tests

- `matrixBytes` liefert für SMILEY, CIRCLE und `level(50)` dieselben Bytes wie `nuimo.py`. Die Erwartungswerte werden einmal mit Python erzeugt und im Test festgehalten.
- Parser für `keys:`, `midi:` und `mode:`, auch mit fehlerhaften Angaben.
- MIDI-Bytes für Note On/Off, CC absolut, CC relativ in beiden Kodierungen und Program Change, jeweils mit Kanal.
- Drehschritte mit Rest.
- Profilauflösung mit Modus, App-Name, Bundle-ID, Fallback und `none`.

### Szenario-Tests ohne Gerät

`Controller` hängt nicht direkt an Hardware oder System:

- Ausgaben gehen über ein Protokoll `Outputs` (Tasten, Medientasten, Scrollen, Shell, Lautstärke, MIDI, Matrix).
- Die aktive App kommt von einem eingespeisten Anbieter.
- `ButtonGestures` bekommt einen einspeisbaren Scheduler, damit Tests ohne Warten auskommen.

Ein `RecordingOutputs` zeichnet alles auf. Beispiele für Szenarien:

- Modus „Resolume“ an, eine volle Umdrehung → CC 20 steigt bis 127 und bleibt dort.
- `hold` belegt → Drücken sendet Note On, Loslassen Note Off, kein `press`.
- TradingView vorne, kurzer Druck → ⌥↩.
- `none` im App-Profil → `[default]` wird nicht ausgeführt.
- Doppelklick innerhalb von 0,35 s → `double_press`, kein `press`.

### Handtests

Siehe Abschnitt 11. Was Bluetooth, Berechtigungen, andere Apps oder Resolume braucht, wird von Hand geprüft.

## 9. Bauen und Signieren

`app/build.sh`:

1. `swift build -c release`.
2. `build/NuimoBar.app` aus Binary, `Info.plist` und `default-config.toml` zusammensetzen.
3. Mit der Identität „Apple Development“ signieren, die per `security find-identity` gefunden wird. Ohne passende Identität wird ad hoc signiert und eine Warnung ausgegeben.

`app/build.sh install` kopiert die App zusätzlich nach `/Applications`. Das ist nötig für einen zuverlässigen Login-Start.

Das Skript wird so aufgebaut, dass sich Developer ID und Notarisierung später als eigener Schritt ergänzen lassen.

## 10. Umsetzungsreihenfolge

1. Gerüst: Package, `Info.plist`, `build.sh`, leere Menüleisten-App, die startet.
2. Protokoll, Matrix und Gesten mit Tests.
3. Bluetooth-Verbindung mit Statusanzeige und Akku, Smiley nach dem Verbinden.
4. Config, Controller und Aktionen, Lautstärke über CoreAudio, Szenario-Tests.
5. MIDI, `hold` und Modi.
6. Menü vervollständigen.
7. Handtest am Gerät und mit Resolume, offene Punkte klären, Spec auf „Umgesetzt“ setzen.

## 11. Abnahme

- [ ] `swift test` läuft ohne Fehler.
- [ ] `codesign -dv build/NuimoBar.app` zeigt die Signatur „Apple Development“.
- [ ] Beim ersten Start erscheinen die Abfragen für Bluetooth und Bedienungshilfen.
- [ ] Das Menü zeigt „Suche …“. Nach einem Druck auf den Nuimo zeigt es „Verbunden“ mit Akku, nach 2 s erscheint der Smiley.
- [ ] Finder vorne: Drücken startet und stoppt Musik, Drehen ändert die Lautstärke mit Pegel auf der Matrix, Wischen springt zum vorigen oder nächsten Titel.
- [ ] TradingView vorne: Das Menü zeigt „Profil: TradingView“, Drehen scrollt, Drücken sendet ⌥↩, Wischen sendet Tab und ⇧Tab.
- [ ] `config.toml` bei laufender App ändern → greift sofort. Syntaxfehler einbauen → das Menü zeigt den Fehler, die alte Belegung bleibt.
- [ ] Debug-Log einschalten → die Datei füllt sich, „Log öffnen …“ funktioniert.
- [ ] Nuimo einschlafen lassen oder außer Reichweite bringen → „Suche …“. Nach einem Druck verbindet er sich von selbst wieder.
- [ ] „Beim Login starten“ einschalten → die App erscheint unter Systemeinstellungen › Allgemein › Anmeldeobjekte und startet nach dem Anmelden.
- [ ] Neu bauen und installieren → die Freigabe für Bedienungshilfen bleibt bestehen.
- [ ] MIDI Monitor zeigt die Quelle „Nuimo“ und die erwarteten Nachrichten.
- [ ] Resolume: Eingang „Nuimo“ aktivieren, im Mapping-Modus einen Parameter per Drehen lernen und regeln. Ebenso einen Clip per Note, einen Effekt per `hold` und Program Change.
- [ ] Resolume: Relativen CC im Modus „Relative“ prüfen und die passende Kodierung als Standard festlegen.
- [ ] Modus „Resolume“ per Menü und per Geste ein- und ausschalten, während eine andere App vorne ist → MIDI kommt an.
- [ ] Nach einem Neustart der App ist der Modus noch aktiv und Resolume erkennt die Zuordnungen wieder.
- [ ] App beenden → `uv run bridge.py` verbindet sich wie bisher.

## 12. Offene Punkte

- Welche relative Kodierung Resolume erwartet.
- Der Name „NuimoBar“ ist ein Arbeitsname.
- Developer ID und Notarisierung, falls die App ohne Warnung weitergegeben werden soll.
- Ein konkreter Anwendungsfall steht noch aus. Er entscheidet, ob und wie ein grafischer Editor folgt.
