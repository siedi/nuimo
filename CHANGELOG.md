# Changelog

All notable changes to this project. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/). The first version of the app will be 0.1.0.

## [Unreleased]

### Added

- Menu bar app: scaffold under `app/` with a SwiftPM package, `Info.plist`, `default-config.toml` and `build.sh`, which builds, bundles and signs with “Apple Development”. The app starts as a menu bar icon without a Dock icon.
- Menu bar app: Nuimo protocol, images and levels for the LED matrix, display queue and button gestures, with tests. The matrix bytes match `nuimo.py`.
- Menu bar app: Bluetooth connection to the Nuimo. The first time, it searches by name; after that a connection request stays open until the Nuimo is reachable. The menu shows connection and battery, and the smiley appears after connecting. For now, gestures only show up in the menu and on the matrix.
- Menu bar app: mapping from `config.toml` with profiles by app name or bundle ID, reload on every change and an error line in the menu while the previous mapping stays active. Keyboard shortcuts, media keys, scrolling, shell commands and volume via CoreAudio, with an image or level on the matrix. On the first start the default mapping is installed and the app asks for the Accessibility permission. Menu item “Edit mapping …”.
- Menu bar app: virtual MIDI source “Nuimo” with a fixed unique ID. Actions `midi:note`, `midi:cc` (absolute when turning, relative, fixed value, trigger), `midi:pc` with their own channel via `@`, settings `midi_channel`, `midi_cc_per_turn` and `midi_relative`.
- Menu bar app: event `hold` for held notes and CCs.
- Menu bar app: modes `[modes.*]`, switched via the “Mode” submenu (only if the file contains modes) or with `mode:<Name>`, `mode:off` and `mode:toggle:<Name>`, with “M” and “X” on the matrix. The active mode survives a restart.
- Menu bar app: optional debug log at `~/Library/Logs/NuimoBar/debug.log`, switched on and off and opened from the menu.
- Menu bar app: German localization via the String Catalog `Localizable.xcstrings`, including the Bluetooth prompt. `build.sh` adds new strings from the source to the catalog and warns about missing translations.
- MIT license.
- Project basics: Git repository, README, conventions in `CLAUDE.md`, mapping reference in `docs/config.md`.
- Spec 001 for the Swift menu bar app, with MIDI output for Resolume and modes.
- Python prototype: `nuimo.py` as a test tool, `bridge.py` as a service with app profiles, `config.toml` with a default and a TradingView mapping.

### Changed

- Documentation, menu texts, terminal output of the scripts and comments in the config files are now in English.
- Comments and docstrings in the Python code are in English.
