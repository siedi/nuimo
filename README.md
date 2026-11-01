# Nuimo

The Senic Nuimo is a rotary knob with a button, a touch surface, a gesture sensor and a 9×9 LED matrix, connected over Bluetooth LE. This project turns it into a controller for the Mac: depending on the app in front, turning, pressing and swiping trigger keyboard shortcuts, scrolling, media keys, volume, shell commands or MIDI messages.

## Why

I found my old Nuimo in a box in the basement. Senic stopped supporting it long ago, but after a night on the charger the matrix lit up again, and the ring still turns as smoothly as I remembered. Too good to go back into the box, so it became a small challenge with Claude Code: get the Nuimo working again without any help from the manufacturer, starting with a Python script that prints every input and ending up with a native menu bar app that also speaks MIDI.

## Parts

- **Python prototype** (`nuimo.py`, `bridge.py`): runs in the terminal and is meant for quick experiments with the device.
- **Menu bar app** (`app/`, work in progress): native Swift app with connection status, launch at login and MIDI output. See [Spec 001](docs/specs/001-menu-bar-app.md).

## Layout

```
nuimo.py                Test tool: prints every input, shared building blocks
bridge.py               Service: turns gestures into actions depending on the app
config.toml             Mapping for bridge.py
docs/config.md          Mapping reference
docs/specs/             Specs, numbered consecutively
app/                    Menu bar app (work in progress)
CHANGELOG.md            Changes
CLAUDE.md               Development conventions for Claude Code
LICENSE                 MIT license
```

## Python prototype

Requires [uv](https://docs.astral.sh/uv/). The dependencies are declared in the scripts themselves, and `uv` installs them on the first run.

```sh
uv run nuimo.py    # print inputs and mirror them on the matrix
uv run bridge.py   # use the Nuimo as a controller according to config.toml
```

Press the Nuimo once before starting so it wakes up. `bridge.py` reconnects on its own after a disconnect and reloads `config.toml` whenever it changes.

The Nuimo allows only one connection at a time. While the app or another script is connected, a second one will not find it.

## Menu bar app

Work in progress according to [Spec 001](docs/specs/001-menu-bar-app.md) §10. The app connects to the Nuimo and runs the mapping, including MIDI and modes. Launch at login and the hints in the menu are still missing. Building requires Xcode with Swift 6, and signing an “Apple Development” certificate. Without one, `build.sh` signs ad hoc.

```sh
cd app
./build.sh           # builds build/NuimoBar.app
./build.sh install   # builds and copies to /Applications
swift test           # tests
```

The app's mapping lives in `~/Library/Application Support/NuimoBar/config.toml` and can be opened from the menu. The format is described in [docs/config.md](docs/config.md).

## Permissions

macOS asks for two permissions on the first start. For the Python prototype they apply to the terminal, for the app to the app itself.

- **Bluetooth:** to connect to the Nuimo.
- **Accessibility** (System Settings › Privacy & Security › Accessibility): to send keyboard shortcuts, media keys and scroll events to other apps. Without it they do not arrive. Volume and MIDI work anyway.

Restart the script or the app after granting Accessibility.

## Nuimo quirks

Tested with firmware 2.0.0 and hardware 1.3:

- A swipe only registers if you swipe all the way to the edge, unlike on a trackpad. Swipes are therefore better suited to rare, deliberate actions.
- The single status LED that marks the top cannot be controlled over Bluetooth. The 9×9 matrix is the only way to give feedback.
- After connecting, the Nuimo shows its own checkmark animation. Wait about 2 s before writing to the matrix, or the image gets overwritten.
- A long press from 0.4 s feels right, 0.6 s was too sluggish.
- One full turn gives a rotation value of about 2650.

## Troubleshooting

- **No Nuimo found:** press it once to wake it up. Check whether another program is still connected.
- **Keyboard shortcuts do not arrive:** check the Accessibility permission and restart the program.
- **Wrong letter:** keys follow the US keyboard layout. On a German keyboard, `y` and `z` are swapped.
- **Mapping has no effect:** look for syntax errors in `config.toml`. `bridge.py` reports them in the terminal, the app in its menu.

## License

MIT, see [LICENSE](LICENSE). The app uses [TOMLKit](https://github.com/LebJe/TOMLKit) (MIT), the Python scripts use [bleak](https://github.com/hbldh/bleak) (MIT) and [PyObjC](https://github.com/ronaldoussoren/pyobjc) (MIT).

This is not an official Senic project and is not affiliated with Senic. “Senic” and “Nuimo” are trademarks of their respective owners.
