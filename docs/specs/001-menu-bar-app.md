# Spec 001: Menu bar app

Status: In progress · Updated: 2026-10-31

## 1. Goal and scope

The Nuimo should control the Mac without a terminal. For this, a native macOS app in Swift sits in the menu bar, shows connection and battery, starts at login and can be passed on to others.

The app takes over the logic and the mapping format of `bridge.py` and adds MIDI, so that the Nuimo can also control Resolume.

Included in v1:

- Everything `bridge.py` does today, with the same mapping format.
- MIDI output for CC, notes, held notes and program change.
- Modes that take precedence over all app profiles and can be switched from the menu or with a gesture.
- Menu with status, active profile, last gesture, launch at login and debug log.

Not in v1:

- Graphical editor for the mapping. It comes once there is a concrete use case.
- Pause switch. To test with the Python scripts, quit the app.
- Distribution without a Gatekeeper warning (Developer ID and notarization).
- MIDI feedback from Resolume.

The Python scripts stay in the project. New ideas are tried on the device with them before they go into a spec and into the app.

## 2. Decisions

| Decision | Reason |
|---|---|
| Swift with SwiftUI instead of Python as an app bundle | Native APIs for Bluetooth, keyboard events and MIDI. Small app, fast start, permissions for Bluetooth and Accessibility work reliably. A bundled Python interpreter would be large and unreliable with permissions. |
| SwiftPM instead of an Xcode project | Builds entirely on the command line, project files are readable and easy to version. The package can still be opened in Xcode. |
| Mapping as TOML with TOMLKit | The format of `config.toml` stays the same. Existing mappings keep working. |
| Volume via CoreAudio instead of `osascript` | No process launch per turn, and the current value can be read fresh on every turn. |
| Pending `connect()` instead of a scan loop | CoreBluetooth keeps a connection request open without a timeout and connects as soon as the Nuimo wakes up. This saves energy and code. |
| No app sandbox | Keyboard and scroll events to other apps do not work reliably in the sandbox. |
| Signing with “Apple Development” | The certificate is available. A stable signature makes the Accessibility permission survive a rebuild. Developer ID follows if needed. |

## 3. Layout

```
nuimo/
  bridge.py, nuimo.py, config.toml    Python prototype
  docs/                                Specs and mapping reference
  app/
    Package.swift                      SwiftPM, macOS 14+, depends on TOMLKit
    .swift-format
    build.sh                           builds, bundles, signs; "install" copies to /Applications
    Resources/
      Info.plist
      default-config.toml
    Sources/NuimoBar/
      NuimoBarApp.swift                @main, MenuBarExtra, menu bar icon
      MenuContent.swift                menu items
      AppModel.swift                   assembles the parts on launch
      AppState.swift                   observable state for the menu
      ConnectionStatus.swift           connection state and status line
      NuimoDevice.swift                CoreBluetooth: scan, connection, notifications, battery
      NuimoProtocol.swift              UUIDs, decoding of sensor data
      Gesture.swift                    trigger events and their matrix image
      MatrixImage.swift                patterns, level, bytes
      MatrixDisplay.swift              display queue
      ButtonGestures.swift             short, long and double press, hold
      Scheduler.swift                  timer as a protocol, so tests do not have to wait
      MainScheduler.swift              timer with real time
      Config.swift                     parse TOML, resolve profiles
      ConfigStore.swift                create the file, reload on change, keep errors
      Settings.swift, Profile.swift    content of the mapping
      Action.swift                     action from the mapping text, with parser
      ActionParseError.swift           errors when parsing an action
      KeyShortcut.swift                keyboard shortcuts and key codes
      KeyModifiers.swift               cmd, shift, ctrl, opt
      MediaKey.swift                   media keys
      FrontmostApp.swift               app in front
      Controller.swift                 event → profile → action
      Outputs.swift                    protocol for all outputs of the controller
      SystemOutputs.swift              outputs of the running app
      SystemActions.swift              keys, media keys, scrolling, shell
      SystemVolume.swift               system volume via CoreAudio
      MIDIOut.swift                    virtual MIDI output
      MIDIMessage.swift                MIDI messages as bytes and UMP
      MIDIAction.swift                 midi: actions with parser
      MIDIRelativeEncoding.swift       encoding of relative CCs
      ControlChangeTracker.swift       CC values and remainders per channel and controller
      ModeAction.swift                 mode: actions with parser
      DebugLog.swift                   debug log to a file, can be switched off
    Tests/NuimoBarTests/
```

`Info.plist`:

- `LSUIElement` = true: no Dock icon.
- `NSBluetoothAlwaysUsageDescription`: reason for the Bluetooth prompt.
- Bundle ID `com.siedler.NuimoBar`, version 0.1.0.

Paths at runtime:

- Mapping: `~/Library/Application Support/NuimoBar/config.toml`. On the first start, `default-config.toml` is copied there.
- Debug log: `~/Library/Logs/NuimoBar/debug.log`.
- App settings (debug log, active mode, Nuimo identifier, MIDI ID): `UserDefaults`.

## 4. Taking over the existing logic

Behavior and constants stay the same. The Python code is the reference in each case.

- **Protocol** (`nuimo.py`, constants at the top):
  - Sensor characteristics `f29b1526` to `f29b1529` with the suffix `-cb19-40f3-be5c-7241ecb82fd2` (fly, swipe, rotation, button).
  - Matrix `f29b1524-cb19-40f3-be5c-7241ecb82fd1`, battery `2a19`.
  - Rotation value as Int16 little-endian, button `data[0]` with 1 = pressed and 0 = released.
  - Swipe codes 0–11 in the order of `SWIPE_EVENTS` in `bridge.py`, fly codes 0 = left and 1 = right.
- **Matrix** (`nuimo.py`: `grid`, `rotate`, patterns, `level`, `matrix_bytes`, `Display`):
  - 11 bytes of pixel bits, then brightness, then display time in 1/10 s.
  - If images arrive faster than BLE can write them, the newest one wins. Writes use a response, and the next image is sent only after `didWriteValueFor`.
  - Send the first image only 2 s after connecting, otherwise the Nuimo's checkmark animation overwrites it.
- **Gestures** (`nuimo.py`: `ButtonGestures`):
  - Long press after 0.4 s, wait for a second press 0.35 s.
  - If the knob is turned while pressed, the press does not count as a click.
- **Mapping** (`bridge.py`: `Config`, `session.profiles`, `on_event`, `on_rotate`):
  - Profile by app name or bundle ID, otherwise `[default]`. `none` stops the fallback.
  - `rotate` and `rotate_pressed` continuously, or in steps via `_left`/`_right` with a remainder per base event.
  - The file is reloaded when its modification date has changed. It is checked on every event. On a syntax error the previous mapping stays active.
- **Actions** (`bridge.py`: `KEYCODES`, `MODIFIERS`, `MEDIA_KEYS`, `send_keys`, `send_scroll`, `send_media`):
  - Keys via `CGEvent` to `.cghidEventTap`.
  - Media keys via `NSEvent.otherEvent` of type `.systemDefined`, subtype 8.
  - Scrolling via scroll events in pixels.
  - `shell:` runs through `/bin/zsh -lc`, so that paths such as Homebrew's apply.
- **Volume** (`bridge.py`: `Volume`): `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` of the default output device.
  - The value is read fresh on every turn. This removes the need to re-read it after 2 s.
  - Devices without a volume control, e.g. HDMI, are reported in the log.

## 5. MIDI

### Output

The app creates a virtual source named “Nuimo” via CoreMIDI (`MIDISourceCreateWithProtocol`, MIDI 1.0). Resolume and other programs see it as a MIDI input.

The `kMIDIPropertyUniqueID` is generated on the first start and stored. This way Resolume recognizes its mappings after the app restarts.

### Actions

Summary; the full description is in [docs/config.md](../config.md):

| Action | Effect |
|---|---|
| `midi:note:<nr>` | Trigger: Note On with velocity 127, Note Off after 50 ms. With `hold`: Note On on press, Note Off on release. |
| `midi:cc:<nr>` | With `rotate`/`rotate_pressed`: absolute value 0–127 that the app tracks per channel and controller. With `hold`: 127 on press, 0 on release. Otherwise: 127, then 0 after 50 ms. |
| `midi:cc:<nr>:relative` | Only with `rotate`/`rotate_pressed`: relative change, encoded according to `midi_relative`. |
| `midi:cc:<nr>=<value>` | Trigger: sends a fixed value 0–127. |
| `midi:pc:<nr>` | Trigger: program change 0–127. |

Every MIDI action can get its own channel with `@<channel>` (1–16), otherwise `midi_channel` applies.

New settings: `midi_channel` (default 1), `midi_cc_per_turn` (default 127, change in value per full turn) and `midi_relative` (default `"twos"`).

There are two encodings for relative CCs:

- `"twos"`: 1 = +1, 127 = −1.
- `"offset"`: 65 = +1, 63 = −1.

Which one Resolume expects in its “Relative” mode is not documented and will be settled in the hand test. At most ±63 steps are sent per message.

Feedback on the matrix:

- Absolute CC: level, as for volume.
- Notes, fixed CC values and program change: the gesture image, as for other actions.

### Event `hold`

If `hold` is set for the active mapping (and is not `none`), the button is passed through directly: press and release each trigger the action immediately. Short, long and double press are then off. Turning still works, including `rotate_pressed`.

Which mapping applies is decided on press. The release always belongs to the same press, even if another app has come to the front in the meantime.

Allowed actions for `hold` are `midi:note:<nr>` and `midi:cc:<nr>`.

### Modes

Sections `[modes.<Name>]` describe mappings that can be switched on regardless of the active app. While a mode is active, the order is mode → app profile → `[default]`.

Switching:

- In the menu via the “Mode” submenu with all modes from the file. The active mode has a checkmark, and clicking it switches it off. If the file has no modes, the submenu is not shown.
- By action: `mode:<Name>`, `mode:off` and `mode:toggle:<Name>`.

When a mode is switched on, the matrix briefly shows an “M”, when it is switched off an “X”:

```
Mode on      Mode off
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

The active mode persists across a restart of the app. If it is missing after the file is reloaded, no mode is active.

## 6. Connection

- `CBCentralManager` on the main queue; the connection code runs on `@MainActor`.
- The first time, the app scans for a device named “Nuimo” and stores its identifier.
- After that, `retrievePeripherals(withIdentifiers:)` and `connect()`. The connection request stays open until the Nuimo is reachable. After a disconnect it is made again immediately.
- If the stored Nuimo can no longer be found, the app scans by name again.
- Read the battery on connect. If the characteristic supports notify, subscribe to it, otherwise read it every 10 minutes.
- If Bluetooth is off or not allowed for the app, the menu shows this.

## 7. Menu

```
◉ Connected · Battery 82 %
  Profile: TradingView
  Last gesture: press → keys:opt+return
⚠ Grant Accessibility …                 (only when needed)
⚠ Error in config.toml: …               (only when needed)
───────────────
  Mode                   ▸  ✓ Resolume     (only with modes)
                              Lights
  Edit mapping …
✓ Launch at login
  Debug log
  Open log …
───────────────
  Quit                                   ⌘Q
```

- The menu bar icon is an SF Symbol and distinguishes connected and disconnected.
- Depending on the situation, the status line shows “Connected · Battery 82 %”, “Connected”, “Searching for Nuimo … (press once)”, “Bluetooth is off”, “Bluetooth not allowed” or “Bluetooth unavailable”.
- The profile line shows “Profile: <App>” or “Profile: Default”. While a mode is active, it shows “Mode: <Name>”.
- The last gesture line shows “Last gesture: event → action”, or “Last gesture: event (not mapped)” if no profile maps the event.
- “Grant Accessibility …” requests the permission and opens the matching page of System Settings. Without the permission, keys, media keys and scrolling do not arrive; MIDI and volume work anyway.
- “Edit mapping …” opens `config.toml` in the default editor.
- “Launch at login” uses `SMAppService.mainApp`.
- “Debug log” writes raw data, gestures, profile resolution, actions, MIDI bytes and errors to the log file. “Open log …” opens it.

Menu texts are in English and go through `String(localized:)`.

## 8. Test concept

### Unit tests

- `matrixBytes` returns the same bytes as `nuimo.py` for SMILEY, CIRCLE and `level(50)`. The expected values are generated once with Python and fixed in the test.
- Parsers for `keys:`, `midi:` and `mode:`, including invalid input.
- MIDI bytes for Note On/Off, absolute CC, relative CC in both encodings and program change, each with a channel.
- Rotation steps with remainder.
- Profile resolution with mode, app name, bundle ID, fallback and `none`.

### Scenario tests without a device

`Controller` does not depend directly on hardware or the system:

- Outputs go through an `Outputs` protocol (keys, media keys, scrolling, shell, volume, MIDI, matrix).
- The active app comes from an injected provider.
- `ButtonGestures` gets an injectable scheduler, so tests do not have to wait.

A `RecordingOutputs` records everything. Example scenarios:

- Mode “Resolume” on, one full turn → CC 20 rises to 127 and stays there.
- `hold` mapped → press sends Note On, release Note Off, no `press`.
- TradingView in front, short press → ⌥↩.
- `none` in the app profile → `[default]` is not executed.
- Double press within 0.35 s → `double_press`, no `press`.

### Hand tests

See section 11. Anything that needs Bluetooth, permissions, other apps or Resolume is checked by hand.

## 9. Building and signing

`app/build.sh`:

1. `swift build -c release`.
2. Assemble `build/NuimoBar.app` from the binary, `Info.plist` and `default-config.toml`.
3. Sign with the “Apple Development” identity found via `security find-identity`. Without a matching identity, sign ad hoc and print a warning.

`app/build.sh install` also copies the app to `/Applications`. This is needed for a reliable launch at login.

The script is structured so that Developer ID and notarization can be added later as a separate step.

## 10. Implementation order

1. Scaffold: package, `Info.plist`, `build.sh`, an empty menu bar app that starts.
2. Protocol, matrix and gestures with tests.
3. Bluetooth connection with status display and battery, smiley after connecting.
4. Config, controller and actions, volume via CoreAudio, scenario tests.
5. MIDI, `hold` and modes.
6. Complete the menu.
7. Hand test on the device and with Resolume, settle open points, set the spec to “Implemented”.

## 11. Acceptance

- [ ] `swift test` runs without errors.
- [ ] `codesign -dv build/NuimoBar.app` shows the “Apple Development” signature.
- [ ] On the first start, the prompts for Bluetooth and Accessibility appear.
- [ ] The menu shows “Searching for Nuimo …”. After a press on the Nuimo it shows “Connected” with the battery, and the smiley appears after 2 s.
- [ ] Finder in front: press starts and stops music, turning changes the volume with a level on the matrix, swiping skips to the previous or next track.
- [ ] TradingView in front: the menu shows “Profile: TradingView”, turning scrolls, press sends ⌥↩, swiping sends Tab and ⇧Tab.
- [ ] Change `config.toml` while the app runs → takes effect immediately. Add a syntax error → the menu shows the error, the previous mapping stays.
- [ ] Switch on the debug log → the file fills up, “Open log …” works.
- [ ] Let the Nuimo fall asleep or move it out of range → “Searching for Nuimo …”. After a press it reconnects on its own.
- [ ] Switch on “Launch at login” → the app appears under System Settings › General › Login Items and starts after logging in.
- [ ] Rebuild and install → the Accessibility permission stays.
- [ ] MIDI Monitor shows the source “Nuimo” and the expected messages.
- [ ] Resolume: enable the input “Nuimo”, learn a parameter by turning in mapping mode and control it. Likewise a clip via note, an effect via `hold` and program change.
- [ ] Resolume: check relative CC in “Relative” mode and set the matching encoding as default.
- [ ] Switch mode “Resolume” on and off from the menu and with a gesture while another app is in front → MIDI arrives.
- [ ] After restarting the app, the mode is still active and Resolume recognizes its mappings.
- [ ] Quit the app → `uv run bridge.py` connects as before.

## 12. Open points

- Which relative encoding Resolume expects.
- The name “NuimoBar” is a working title.
- Developer ID and notarization, in case the app is to be passed on without a warning.
- A concrete use case is still missing. It decides whether and how a graphical editor follows.
