# Nuimo

At the start of every session, read `.claude/handoff.md` if it exists. It is written by `/feierabend` and is not committed.

Senic Nuimo as a controller for the Mac. The Python prototype (`nuimo.py`, `bridge.py`) works. The Swift menu bar app under `app/` is work in progress, see [Spec 001](docs/specs/001-menu-bar-app.md). Overview and device knowledge are in the [README](README.md), the mapping format in [docs/config.md](docs/config.md).

## Language

- **English:** everything in the repository: code, comments, docs (README, `docs/`, CHANGELOG), commit messages, UI texts in the source (menu, messages, terminal output of the scripts), comments in `config.toml` and `default-config.toml`, debug log messages.
- **German:** the conversation with the maintainer and the German translations in the String Catalogs.

## Markdown

One paragraph is one line, one list item as well. No hard line wraps.

## Workflow for new features

1. Try it on the device with the Python scripts if the hardware behavior is unclear.
2. Write it down in a spec: `docs/specs/NNN-name.md`, numbered consecutively, with a status line (Draft, In progress, Implemented).
3. Implement it in Swift.
4. Update `docs/config.md`, `app/Resources/default-config.toml` and `CHANGELOG.md`.

`docs/config.md` is the binding description of the format. Changes to the format start there.

## Swift

- Swift API Design Guidelines.
- Swift 6 language mode with strict concurrency. App state and hardware access run on `@MainActor`.
- Format with `swift format` (part of the toolchain) and the configuration in `app/.swift-format`.
- `///` docs for types and functions whose purpose is not obvious.
- No force unwraps, except for constants and in tests.
- One building block per file.
- Tests with Swift Testing (`import Testing`), run with `swift test` in `app/`.
- UI texts via `String(localized:)` in English, `defaultLocalization` is `"en"`. The German translation goes into `app/Resources/Localizable.xcstrings` (`InfoPlist.xcstrings` for `Info.plist` texts). `build.sh` adds new strings to the catalog and warns about missing translations; fill them in before committing.
- Build with `app/build.sh`, not just `swift build`, so the bundle and signature are right. `app/build.sh install` also copies the app to `/Applications`. Signing needs an “Apple Development” certificate, see the README.

## Python

- PEP 8 and type hints.
- Dependencies as inline metadata (`# /// script`), run with `uv run <script>.py`.
- The scripts are a prototype and test tool, not a second production solution. New features go into the app; the scripts only get what is needed to try things on the device.

## Testability

Logic stays testable without hardware. Bluetooth, system calls (keys, volume, shell), MIDI, the active app and time go through protocols or injected dependencies. Whatever can only be checked by hand goes into the acceptance checklist of the respective spec.

## Versions and Git

- Versions follow SemVer, the app starts at 0.1.0. The version is in `app/Resources/Info.plist`.
- `CHANGELOG.md` follows Keep a Changelog, changes go under `[Unreleased]` first.
- Tag `vX.Y.Z` per release.
- Small, topical commits. Claude commits only when asked.
- No “Co-Authored-by” lines or other references to Claude in commit messages.
