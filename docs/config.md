# Mapping (config.toml)

This file is the binding description of the mapping format. If the format changes, this file is updated first, then `app/Resources/default-config.toml` and the CHANGELOG.

The file lives in two places:

- **App:** `~/Library/Application Support/NuimoBar/config.toml`. The menu opens it via “Edit mapping …”.
- **Python bridge:** `config.toml` next to `bridge.py`.

Changes take effect immediately, without a restart. If the file contains a syntax error, the previous mapping stays active. The app shows the error in the menu, `bridge.py` prints it in the terminal.

Some entries are only understood by the app, see [Differences from bridge.py](#differences-from-bridgepy).

## Structure

```toml
[settings]           # settings
[default]            # default profile
[apps.TradingView]   # profile for one app
[modes.Resolume]     # mode, app only
```

Each profile maps events to actions: `event = "action"`.

**Apps** are recognized by their name as shown in the Dock, or by their bundle ID. Names with spaces go in quotes: `[apps."Google Chrome"]`, `[apps."Resolume Arena"]`.

**Modes** apply regardless of the app in front. They are switched on from the menu or with a `mode:` action. At most one mode is active at a time. The active mode is kept across a restart of the app. If it disappears from the file, no mode is active. For `mode:<Name>` with a name the file does not contain, the app writes a message to the debug log and does nothing else.

### Resolution order

For each event, the profiles are searched in this order:

1. the active mode, if one is switched on
2. the profile of the app in front
3. `[default]`

The first profile that contains the event decides. `none` deliberately silences an event; the following profiles are then not consulted.

For rotation, the first profile that contains either `rotate` or `rotate_left`/`rotate_right` decides. The same applies to `rotate_pressed`.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `scroll_speed` | `0.5` | Pixels per rotation unit for `scroll`. A negative value reverses the direction. |
| `rotate_step` | `300` | Rotation units per step for `rotate_left`/`rotate_right`. One full turn is about 2650. |
| `midi_channel` | `1` | MIDI channel 1–16 used when an action does not specify one. App only. |
| `midi_cc_per_turn` | `127` | Change of a CC value per full turn. App only. |
| `midi_relative` | `"twos"` | Encoding for relative CCs: `"twos"` (1 = +1, 127 = −1) or `"offset"` (65 = +1, 63 = −1). App only. |

## Events

### Button

| Event | Trigger |
|---|---|
| `press` | short press. Reported only after 0.35 s, because a second press might follow. |
| `double_press` | two short presses within 0.35 s |
| `long_press` | button held for 0.4 s |
| `hold` | press and release separately, without delay. If `hold` is mapped, `press`, `double_press` and `long_press` are off. App only. |

If the knob is turned while the button is down, the press counts neither as `press` nor as `long_press`.

### Swipe, touch, hand

| Event | Trigger |
|---|---|
| `swipe_left`, `swipe_right`, `swipe_up`, `swipe_down` | swipe across the surface. Only registers if you swipe all the way to the edge. |
| `touch_left`, `touch_right`, `touch_top`, `touch_bottom` | short tap on the edge |
| `longtouch_left`, `longtouch_right`, `longtouch_top`, `longtouch_bottom` | long touch on the edge |
| `fly_left`, `fly_right` | move a hand left or right above the Nuimo |

### Rotation

| Event | Trigger |
|---|---|
| `rotate` | turning, continuous. Allowed: `volume`, `scroll`, `midi:cc`. |
| `rotate_pressed` | turning with the button down, continuous. Allowed as for `rotate`. |
| `rotate_left`, `rotate_right` | turning in steps of `rotate_step`. All trigger actions are allowed. |
| `rotate_pressed_left`, `rotate_pressed_right` | as above, with the button down |

## Actions

### For triggers

Triggers are all events except `rotate`, `rotate_pressed` and `hold`.

| Action | Effect |
|---|---|
| `keys:<shortcut>` | keyboard shortcut, e.g. `keys:opt+return`, `keys:cmd+shift+4`. See [Keys](#keys). |
| `media:<key>` | media key: `playpause`, `next`, `previous`, `mute` |
| `shell:<command>` | shell command, e.g. `shell:shortcuts run 'Lights on'`. The app uses `/bin/zsh -lc`, the bridge `/bin/sh`. |
| `midi:note:<nr>` | Note On (velocity 127), Note Off after 50 ms. `nr` 0–127. App only. |
| `midi:cc:<nr>` | CC value 127, then 0 after 50 ms. App only. |
| `midi:cc:<nr>=<value>` | CC with a fixed value 0–127. App only. |
| `midi:pc:<nr>` | Program Change 0–127. App only. |
| `mode:<Name>` | switch a mode on. App only. |
| `mode:off` | switch the mode off. App only. |
| `mode:toggle:<Name>` | switch a mode on or off. App only. |
| `none` | do nothing, not even what a following profile contains |

### For rotation (`rotate`, `rotate_pressed`)

| Action | Effect |
|---|---|
| `volume` | system volume, with a level on the matrix |
| `scroll` | mouse wheel at the pointer position. With keys: `scroll:ctrl+opt`. |
| `midi:cc:<nr>` | absolute CC value 0–127, with a level on the matrix. The app keeps the value per channel and controller while it runs. It starts at 0. App only. |
| `midi:cc:<nr>:relative` | relative change, encoded according to `midi_relative`. App only. |
| `none` | do nothing |

### For `hold`

| Action | Effect |
|---|---|
| `midi:note:<nr>` | Note On on press, Note Off on release |
| `midi:cc:<nr>` | value 127 on press, 0 on release |
| `none` | silence `hold`; `press`, `double_press` and `long_press` apply again |

For any other action under `hold`, the app writes a message to the debug log and treats the press as if `hold` were not mapped.

### MIDI channel

Every MIDI action can get its own channel 1–16 with `@<channel>` at the end, e.g. `midi:note:36@10` or `midi:cc:21:relative@2`. Without it, `midi_channel` applies.

For this, the app provides a virtual MIDI output named “Nuimo”. In Resolume, enable it as an input under Preferences › MIDI.

### Keys

A shortcut consists of zero or more modifiers and exactly one key, joined with `+`.

- Modifiers: `cmd`, `shift`, `ctrl`, `opt` (also `alt`).
- Letters and digits: `a`–`z`, `0`–`9`.
- Characters: `-`, `=`, `[`, `]`, `\`, `;`, `'`, `,`, `.`, `/`, `` ` ``.
- Special keys: `return`, `enter`, `tab`, `space`, `delete`, `forwarddelete`, `escape`, `home`, `end`, `pageup`, `pagedown`, `left`, `right`, `up`, `down`.
- Function keys: `f1`–`f20`.

Keys follow their position on the US keyboard. On a German keyboard, `y` and `z` are therefore swapped, and characters such as `-` or `/` are on different keys than printed.

## Feedback on the matrix

| What | Image |
|---|---|
| `press`, `long_press`, `double_press` | smiley, filled circle, two dots |
| swipe, `fly_*` | arrow in the respective direction |
| touch, long touch | dot at the respective edge |
| `volume`, absolute `midi:cc` | level |
| mode on / off | “M” / “X”, app only |

An image only appears when an action was performed, not for `none` or unmapped events.

## Examples

### Default and TradingView

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
press = "keys:opt+return"      # maximize the active chart / back
swipe_right = "keys:tab"       # next chart
swipe_left = "keys:shift+tab"  # previous chart
```

### Resolume as a mode

The mode is switched on and off with a long touch at the top and then applies even while another app is in front.

```toml
[settings]
midi_channel = 1
midi_cc_per_turn = 127
midi_relative = "twos"

[default]
longtouch_top = "mode:toggle:Resolume"

[modes.Resolume]
rotate = "midi:cc:20"                  # e.g. layer opacity
rotate_pressed = "midi:cc:21:relative" # e.g. effect amount, set to "Relative" in Resolume
hold = "midi:note:40"                  # flash while held
swipe_right = "midi:note:36"           # next clip
swipe_left = "midi:note:37"            # previous clip
fly_left = "midi:pc:0"                 # composition 1
fly_right = "midi:pc:1"                # composition 2
longtouch_top = "mode:toggle:Resolume"
```

Because `hold` is mapped, this mode has no `press`, `double_press` or `long_press`.

### Resolume only while it is in front

```toml
[apps."Resolume Arena"]
rotate = "midi:cc:20"
press = "midi:note:36@2"
```

## Differences from bridge.py

The Python bridge is a prototype and only understands part of the format:

| Entry | App | bridge.py |
|---|---|---|
| `[settings]`, `[default]`, `[apps.*]` | yes | yes |
| `keys`, `media`, `volume`, `scroll`, `shell`, `none` | yes | yes |
| `[modes.*]`, `mode:*` | yes | no |
| `midi:*`, `midi_*` settings | yes | no |
| `hold` event | yes | no |

`bridge.py` reports unknown actions such as `midi:*` or `mode:*` in the terminal and does not run them. It skips `[modes.*]` sections, the `midi_*` settings and the `hold` event without a message.
