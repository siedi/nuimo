# Changelog

Alle nennenswerten Änderungen an diesem Projekt. Das Format folgt [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen folgen [Semantic Versioning](https://semver.org/lang/de/). Die erste Version der App wird 0.1.0.

## [Unreleased]

### Hinzugefügt

- Menüleisten-App: Gerüst unter `app/` mit SwiftPM-Paket, `Info.plist`, `default-config.toml` und `build.sh`, das baut, bündelt und mit „Apple Development“ signiert. Die App startet als Menüleisten-Symbol ohne Dock-Symbol.
- Menüleisten-App: Nuimo-Protokoll, Bilder und Pegel für die LED-Matrix, Display-Warteschlange und Tastengesten, mit Tests. Die Bytes der Matrix stimmen mit `nuimo.py` überein.
- Menüleisten-App: Bluetooth-Verbindung zum Nuimo. Beim ersten Mal wird nach dem Namen gesucht, danach bleibt ein Verbindungswunsch offen, bis der Nuimo erreichbar ist. Das Menü zeigt Verbindung und Akku, nach dem Verbinden erscheint der Smiley. Gesten erscheinen vorerst nur im Menü und auf der Matrix.
- Menüleisten-App: Belegung aus `config.toml` mit Profilen nach App-Name oder Bundle-ID, Neuladen bei jeder Änderung und Fehleranzeige im Menü, wobei die alte Belegung aktiv bleibt. Tastenkürzel, Medientasten, Scrollen, Shell-Befehle und Lautstärke über CoreAudio, mit Bild oder Pegel auf der Matrix. Beim ersten Start wird die Standardbelegung angelegt und nach der Freigabe für Bedienungshilfen gefragt. Menüpunkt „Belegung bearbeiten …“.
- Menüleisten-App: abschaltbares Debug-Log unter `~/Library/Logs/NuimoBar/debug.log`, im Menü ein- und auszuschalten und zu öffnen.
- Projektgrundlage: Git-Repository, README, Konventionen in `CLAUDE.md`, Referenz der Belegung in `docs/config.md`.
- Spec 001 für die Menüleisten-App in Swift, mit MIDI-Ausgang für Resolume und Modi.
- Python-Prototyp: `nuimo.py` als Testwerkzeug, `bridge.py` als Dienst mit App-Profilen, `config.toml` mit Standard- und TradingView-Belegung.

### Geändert

- Kommentare und Docstrings im Python-Code auf Englisch. Die Ausgaben im Terminal bleiben deutsch.
