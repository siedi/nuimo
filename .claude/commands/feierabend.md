---
name: feierabend
description: Session sauber abschließen. Arbeitsstand sichten, Format und Doku abgleichen, Tests laufen lassen, Memory und Handoff für die nächste Session schreiben.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

### Ziel

Die Session mit möglichst wenigen Schritten abschließen. Danach stimmen Doku, Memory und Spec mit dem Stand überein, und `.claude/handoff.md` trägt ihn in die nächste Session.

Lesen, prüfen und zusammenfassen darfst du selbst. **Bevor du Dateien schreibst oder committest, zeigen, was und warum, und Bestätigung abwarten.** Ausnahme: `.claude/handoff.md` schreibst du ohne Rückfrage.

Das Repo ist lokal und hat kein Remote. Es gibt keine Issues und kein CI. Offene Punkte stehen im Handoff und, wenn sie zu einer Spec gehören, in deren Abschnitt „Offene Punkte“.

### Ablauf

#### 1. Lage, ein Aufruf

```bash
git status --short; git log --oneline -10; git log -10 --format=%B | grep -inE "co-authored-by|generated with|noreply@anthropic"
```

- In 3–6 Stichpunkten zusammenfassen, was die Session geändert hat und welche Entscheidungen mit welcher Begründung gefallen sind.
- Uncommittete Änderungen: thematisch gruppierte Commits mit deutscher Message vorschlagen und erst nach Bestätigung committen. Keine Attribution, kein Hinweis auf Claude.
- Trifft die `grep`-Zeile etwas, den Commit melden.

#### 2. Prüfen, was die Session angefasst hat

Nur für geänderte Bereiche, sonst überspringen:

- **Swift (`app/`):** `swift test` und `swift format lint --recursive Sources Tests` in `app/`. Bei Änderungen an Bundle, `Info.plist` oder `build.sh` zusätzlich `./build.sh`. Ergebnis nennen, nicht selbst formatieren.
- **Python:** `python3 -m py_compile nuimo.py bridge.py`.
- **Sprache:** Kommentare, Docstrings und Bezeichner im Code englisch, Doku und Texte in der Oberfläche deutsch. Abweichungen in geänderten Dateien melden.
- **TODO, FIXME, HACK** in geänderten Dateien: nennen und in den Handoff übernehmen.

#### 3. Format und Doku abgleichen

`docs/config.md` ist die verbindliche Beschreibung der Belegung. Hat die Session Ereignisse, Aktionen oder Einstellungen geändert, müssen diese Stellen dazu passen:

- `docs/config.md`
- `app/Resources/default-config.toml`, sobald es sie gibt
- `config.toml` und `bridge.py`, wenn die Bridge die Angabe auch kennt, sonst die Tabelle „Unterschiede zu bridge.py“
- `CHANGELOG.md` unter `[Unreleased]`

Außerdem:

- **Spec:** Status und Abnahme-Checkliste der betroffenen Spec unter `docs/specs/` an den Stand anpassen. Erledigte Punkte abhaken, geklärte offene Punkte mit Ergebnis eintragen.
- **README:** Neues Wissen über das Gerät gehört in den Abschnitt „Eigenheiten des Nuimo“. Geänderte Befehle zum Bauen und Starten ebenso.
- **CLAUDE.md:** nur dauerhafte Regeln. Stand und nächste Schritte gehören in den Handoff.

Bei Abweichungen melden, welche Seite vermutlich neuer ist, und fragen, welche gilt. Geplante Änderungen zeigen, dann schreiben.

#### 4. Memory

`MEMORY.md` steht schon im Kontext, der Pfad im System-Prompt. Nur die Dateien öffnen, die sich ändern.

- Projektstand in `nuimo-project-status.md` auf den Stand bringen.
- Neu nur, was nicht in Code, Git, README, Specs oder `CLAUDE.md` steht, zum Beispiel Rückmeldungen zur Arbeitsweise oder verworfene Ansätze mit Grund.
- Veraltetes korrigieren, Falsches löschen, relative Datumsangaben in absolute umwandeln.

#### 5. Prozesse

Der Nuimo erlaubt nur eine Verbindung. Laufende `bridge.py`, `nuimo.py` oder eine gestartete `NuimoBar.app` auflisten und anbieten, sie zu beenden:

```bash
pgrep -fl "bridge.py|nuimo.py|NuimoBar"
```

#### 6. Handoff

`.claude/handoff.md` überschreiben und dem User den Inhalt zeigen:

```markdown
# Session-Handoff [YYYY-MM-DD]

## Erledigt
## Offen
## Nächste Schritte (konkret, wo weitergemacht wird)
## Geändert an Doku und Memory
## Status (Commits, Tests, laufende Prozesse)
```

Die Datei wird nicht committet. Die nächste Session liest sie zu Beginn, so steht es in `CLAUDE.md`.

### Regeln

- **Nichts committen ohne Bestätigung.** Es gibt kein Remote, also auch nichts zu pushen.
- **Keine Formatter mit Autofix.** Nur prüfen und melden.
- **Kein Subagent.**
- **Deutsch** mit dem User und in der Doku, Englisch im Code.
- **Markdown:** ein Absatz bzw. Listenpunkt pro Zeile.
- **Kein Hinweis auf Claude oder KI** in Commits, Handoff oder Doku.

$ARGUMENTS

---
*v1.0 — 2026-10-31 — neu angelegt. Matthias Siedler*
