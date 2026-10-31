# Nuimo

Zu Beginn jeder Session `.claude/handoff.md` lesen, falls vorhanden. Sie entsteht mit `/feierabend` und wird nicht committet.

Senic Nuimo als Controller für den Mac. Der Python-Prototyp (`nuimo.py`, `bridge.py`) läuft. Die Menüleisten-App in Swift unter `app/` ist im Aufbau, siehe [Spec 001](docs/specs/001-menueleisten-app.md). Überblick und Gerätewissen stehen im [README](README.md), das Format der Belegung in [docs/config.md](docs/config.md).

## Sprache

- **Deutsch:** Dokumentation (README, `docs/`, CHANGELOG), Commit-Messages, Texte in der Oberfläche (Menü, Meldungen, Terminal-Ausgaben der Skripte), Kommentare in `config.toml` und `default-config.toml`.
- **Englisch:** alles im Code, also Bezeichner, Kommentare, Docstrings und Meldungen im Debug-Log.

## Markdown

Ein Absatz ist eine Zeile, ein Listenpunkt ebenso. Keine festen Zeilenumbrüche.

## Ablauf für Neues

1. Am Gerät mit den Python-Skripten ausprobieren, wenn Hardware-Verhalten unklar ist.
2. In einer Spec festhalten: `docs/specs/NNN-name.md`, fortlaufend nummeriert, mit Statuszeile (Entwurf, In Arbeit, Umgesetzt).
3. In Swift umsetzen.
4. `docs/config.md`, `app/Resources/default-config.toml` und `CHANGELOG.md` nachziehen.

`docs/config.md` ist die verbindliche Beschreibung des Formats. Änderungen am Format beginnen dort.

## Swift

- Swift API Design Guidelines.
- Swift 6 Language Mode mit strikter Concurrency. App-Zustand und Hardware-Anbindung laufen auf `@MainActor`.
- Formatieren mit `swift format` (im Toolchain enthalten) und der Konfiguration in `app/.swift-format`.
- `///`-Doku für Typen und Funktionen, deren Zweck nicht offensichtlich ist.
- Keine Force-Unwraps, außer bei Konstanten und in Tests.
- Ein Baustein pro Datei.
- Tests mit Swift Testing (`import Testing`), ausführen mit `swift test` in `app/`.
- UI-Texte über `String(localized:)`, `defaultLocalization` ist `"de"`.
- Bauen mit `app/build.sh`, nicht nur mit `swift build`, damit Bundle und Signatur stimmen.

## Python

- PEP 8 und Type Hints.
- Abhängigkeiten als Inline-Metadaten (`# /// script`), Start mit `uv run <skript>.py`.
- Die Skripte sind Prototyp- und Testwerkzeug, keine zweite Produktivlösung. Neue Funktionen kommen in die App, in die Skripte nur, was zum Ausprobieren am Gerät nötig ist.

## Testbarkeit

Logik bleibt ohne Hardware testbar. Bluetooth, Systemaufrufe (Tasten, Lautstärke, Shell), MIDI, die aktive App und die Zeit laufen über Protokolle oder eingespeiste Abhängigkeiten. Was sich nur von Hand prüfen lässt, steht in der Abnahme-Checkliste der jeweiligen Spec.

## Versionen und Git

- Versionen nach SemVer, die App beginnt bei 0.1.0. Die Version steht in `app/Resources/Info.plist`.
- `CHANGELOG.md` nach Keep a Changelog, Änderungen zuerst unter `[Unreleased]`.
- Tag `vX.Y.Z` pro Veröffentlichung.
- Kleine, thematische Commits. Claude committet nur auf Anweisung.
- Keine „Co-Authored-by“-Zeilen oder andere Hinweise auf Claude in Commit-Messages.
