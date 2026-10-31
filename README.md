# Nuimo

Der Senic Nuimo ist ein Drehknopf mit Taste, Touch-Oberfläche, Gestensensor und 9×9-LED-Matrix, angebunden über Bluetooth LE. Dieses Projekt macht ihn zum Controller für den Mac: Je nach App, die vorne ist, lösen Drehen, Drücken und Wischen Tastenkürzel, Scrollen, Medientasten, Lautstärke, Shell-Befehle oder MIDI-Signale aus.

Es gibt zwei Teile:

- **Python-Prototyp** (`nuimo.py`, `bridge.py`): läuft im Terminal und dient zum schnellen Ausprobieren am Gerät.
- **Menüleisten-App** (`app/`, im Aufbau): native Swift-App mit Verbindungsanzeige, Login-Start und MIDI-Ausgang. Siehe [Spec 001](docs/specs/001-menueleisten-app.md).

## Aufbau

```
nuimo.py                Testwerkzeug: zeigt alle Eingaben an, gemeinsame Bausteine
bridge.py               Dienst: setzt Gesten je nach App in Aktionen um
config.toml             Belegung für bridge.py
docs/config.md          Referenz der Belegung
docs/specs/             Specs, fortlaufend nummeriert
app/                    Menüleisten-App (im Aufbau)
CHANGELOG.md            Änderungen
CLAUDE.md               Konventionen für die Entwicklung
```

## Python-Prototyp

Voraussetzung ist [uv](https://docs.astral.sh/uv/). Die Abhängigkeiten stehen in den Skripten selbst, `uv` installiert sie beim ersten Start.

```sh
uv run nuimo.py    # Eingaben anzeigen und auf der Matrix spiegeln
uv run bridge.py   # Nuimo als Controller nach config.toml
```

Den Nuimo vor dem Start einmal drücken, damit er aufwacht. `bridge.py` verbindet sich nach einer Trennung von selbst neu und lädt `config.toml` bei jeder Änderung neu.

Der Nuimo erlaubt nur eine Verbindung gleichzeitig. Läuft die App oder ein anderes Skript, findet ein zweites ihn nicht.

## Menüleisten-App

Im Aufbau nach [Spec 001](docs/specs/001-menueleisten-app.md) §10. Die App verbindet sich mit dem Nuimo und zeigt Verbindung, Akku und die letzte Geste. Aktionen führt sie noch nicht aus. Voraussetzung ist Xcode mit Swift 6, zum Signieren ein Zertifikat „Apple Development“.

```sh
cd app
./build.sh           # baut build/NuimoBar.app
./build.sh install   # baut und kopiert nach /Applications
swift test           # Tests
```

Die Belegung der App liegt unter `~/Library/Application Support/NuimoBar/config.toml` und lässt sich über das Menü öffnen. Das Format beschreibt [docs/config.md](docs/config.md).

## Berechtigungen

macOS fragt beim ersten Start nach zwei Freigaben. Beim Python-Prototyp gelten sie für das Terminal, bei der App für die App selbst.

- **Bluetooth:** für die Verbindung zum Nuimo.
- **Bedienungshilfen** (Systemeinstellungen › Datenschutz & Sicherheit › Bedienungshilfen): zum Senden von Tastenkürzeln, Medientasten und Scroll-Events an andere Apps. Ohne diese Freigabe kommen sie nicht an. Lautstärke und MIDI funktionieren trotzdem.

Nach dem Erteilen der Bedienungshilfen-Freigabe das Skript bzw. die App neu starten.

## Eigenheiten des Nuimo

Am Gerät getestet mit Firmware 2.0.0 und Hardware 1.3:

- Wischen kommt nur an, wenn man ganz bis zum Rand wischt, nicht wie auf einem Trackpad. Wischen eignet sich deshalb eher für seltene, bewusste Aktionen.
- Die einzelne Status-LED, die anzeigt, wo oben ist, lässt sich nicht über Bluetooth steuern. Für Rückmeldungen steht nur die 9×9-Matrix zur Verfügung.
- Nach dem Verbinden zeigt der Nuimo eine eigene Haken-Animation. Die Matrix erst etwa 2 s später beschreiben, sonst wird das Bild überschrieben.
- Ein langer Druck ab 0,4 s fühlt sich gut an, 0,6 s war zu träge.
- Eine volle Umdrehung ergibt einen Drehwert von etwa 2650.

## Fehlersuche

- **Kein Nuimo gefunden:** einmal drücken, damit er aufwacht. Prüfen, ob noch ein anderes Programm verbunden ist.
- **Tastenkürzel kommen nicht an:** Freigabe unter Bedienungshilfen prüfen und das Programm neu starten.
- **Falscher Buchstabe:** Tasten folgen der US-Tastatur, auf einer deutschen Tastatur sind `y` und `z` vertauscht.
- **Belegung greift nicht:** auf Syntaxfehler in `config.toml` achten. `bridge.py` meldet sie im Terminal, die App im Menü.
