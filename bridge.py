# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "bleak",
#   "pyobjc-framework-Quartz",
#   "pyobjc-framework-Cocoa",
#   "pyobjc-framework-ApplicationServices",
# ]
# ///
"""Nuimo als Mac-Controller: Gesten lösen je nach aktiver App Tastenkürzel, Scrollen, Medientasten usw. aus.

Die Belegung steht in config.toml neben diesem Skript.
"""

import asyncio
import subprocess
import time
import tomllib
from pathlib import Path

import Quartz
from AppKit import NSEvent, NSWorkspace
from ApplicationServices import AXIsProcessTrustedWithOptions, kAXTrustedCheckOptionPrompt
from bleak import BleakClient, BleakScanner
from Foundation import NSDate, NSRunLoop

from nuimo import (
    ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT, ARROW_UP, BATTERY, BUTTON, CIRCLE, DOT_BOTTOM, DOT_LEFT,
    DOT_RIGHT, DOT_TOP, FLY, ROTATION, ROTATION_PER_TURN, SMILEY, SWIPE, TWO_DOTS,
    ButtonGestures, Display, level,
)

CONFIG = Path(__file__).with_name("config.toml")

SWIPE_EVENTS = [
    "swipe_left", "swipe_right", "swipe_up", "swipe_down",
    "touch_left", "touch_right", "touch_top", "touch_bottom",
    "longtouch_left", "longtouch_right", "longtouch_top", "longtouch_bottom",
]
FLY_EVENTS = {0: "fly_left", 1: "fly_right"}

PATTERNS = {
    "press": SMILEY, "long_press": CIRCLE, "double_press": TWO_DOTS,
    "swipe_left": ARROW_LEFT, "swipe_right": ARROW_RIGHT, "swipe_up": ARROW_UP, "swipe_down": ARROW_DOWN,
    "fly_left": ARROW_LEFT, "fly_right": ARROW_RIGHT,
    "touch_left": DOT_LEFT, "touch_right": DOT_RIGHT, "touch_top": DOT_TOP, "touch_bottom": DOT_BOTTOM,
    "longtouch_left": DOT_LEFT, "longtouch_right": DOT_RIGHT, "longtouch_top": DOT_TOP,
    "longtouch_bottom": DOT_BOTTOM,
}

# Virtuelle Tastencodes von macOS (Position auf der US-Tastatur)
KEYCODES = {
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
    "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
    "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34,
    "p": 35, "return": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
    "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50, "delete": 51, "escape": 53,
    "enter": 76, "home": 115, "pageup": 116, "forwarddelete": 117, "end": 119, "pagedown": 121,
    "left": 123, "right": 124, "down": 125, "up": 126,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101,
    "f10": 109, "f11": 103, "f12": 111, "f13": 105, "f14": 107, "f15": 113, "f16": 106, "f17": 64,
    "f18": 79, "f19": 80, "f20": 90,
}
MODIFIERS = {
    "cmd": Quartz.kCGEventFlagMaskCommand,
    "shift": Quartz.kCGEventFlagMaskShift,
    "ctrl": Quartz.kCGEventFlagMaskControl,
    "opt": Quartz.kCGEventFlagMaskAlternate,
    "alt": Quartz.kCGEventFlagMaskAlternate,
}
MEDIA_KEYS = {"playpause": 16, "next": 17, "previous": 18, "mute": 7}  # NX_KEYTYPE_*


class Config:
    """Liest config.toml und lädt sie neu, sobald sich die Datei ändert."""

    def __init__(self):
        self.mtime = None
        self.data = {}

    def get(self) -> dict:
        mtime = CONFIG.stat().st_mtime
        if mtime != self.mtime:
            self.mtime = mtime
            try:
                self.data = tomllib.loads(CONFIG.read_text())
                print("config.toml geladen")
            except tomllib.TOMLDecodeError as e:
                print("Fehler in config.toml, alte Belegung bleibt:", e)
        return self.data


def frontmost_app() -> tuple[str, str]:
    # Ohne kurz laufende Runloop liefert NSWorkspace den Stand vom Programmstart
    NSRunLoop.currentRunLoop().runUntilDate_(NSDate.dateWithTimeIntervalSinceNow_(0.005))
    app = NSWorkspace.sharedWorkspace().frontmostApplication()
    return app.localizedName(), app.bundleIdentifier()


def modifier_flags(names: list[str]) -> int:
    flags = 0
    for name in names:
        flags |= MODIFIERS[name]
    return flags


def send_keys(spec: str):
    *mods, key = spec.lower().split("+")
    flags = modifier_flags(mods)
    for down in (True, False):
        event = Quartz.CGEventCreateKeyboardEvent(None, KEYCODES[key], down)
        Quartz.CGEventSetFlags(event, flags)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)


def send_scroll(pixels: float, modifiers: str = ""):
    event = Quartz.CGEventCreateScrollWheelEvent(None, Quartz.kCGScrollEventUnitPixel, 1, round(pixels))
    if modifiers:
        Quartz.CGEventSetFlags(event, modifier_flags(modifiers.lower().split("+")))
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)


def send_media(name: str):
    code = MEDIA_KEYS[name]
    for flags in (0xA00, 0xB00):  # Taste unten, Taste oben
        event = NSEvent.otherEventWithType_location_modifierFlags_timestamp_windowNumber_context_subtype_data1_data2_(
            14, (0, 0), flags, 0, 0, None, 8, (code << 16) | flags, -1
        )
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, event.CGEvent())


class Volume:
    """Systemlautstärke; bei schnellem Drehen wird nur der jeweils neueste Wert gesetzt."""

    def __init__(self):
        self.value = 0.0
        self.last_change = 0.0
        self.ready = asyncio.Event()
        self.task = asyncio.create_task(self._run())

    def change(self, percent: float) -> float:
        # Nach einer Pause neu einlesen, die Lautstärke kann sich über die Tastatur geändert haben
        if time.monotonic() - self.last_change > 2:
            out = subprocess.run(
                ["osascript", "-e", "output volume of (get volume settings)"], capture_output=True, text=True
            )
            self.value = float(out.stdout.strip() or 0)
        self.last_change = time.monotonic()
        self.value = max(0.0, min(100.0, self.value + percent))
        self.ready.set()
        return self.value

    async def _run(self):
        while True:
            await self.ready.wait()
            self.ready.clear()
            proc = await asyncio.create_subprocess_exec(
                "osascript", "-e", f"set volume output volume {round(self.value)}"
            )
            await proc.wait()


async def session(client: BleakClient, config: Config, volume: Volume):
    battery = (await client.read_gatt_char(BATTERY))[0]
    print(f"Verbunden. Akku: {battery} %")
    display = Display(client)
    rotation_rest = {}  # angefangene Schritte bei rotate_left/right

    def profiles() -> tuple[str, list[dict]]:
        data = config.get()
        name, bundle = frontmost_app()
        apps = data.get("apps", {})
        return name, [apps.get(name) or apps.get(bundle) or {}, data.get("default", {})]

    def perform(app: str, event: str, action: str):
        print(f"[{app}] {event} → {action}")
        kind, _, arg = action.partition(":")
        try:
            if kind == "keys":
                send_keys(arg)
            elif kind == "media":
                send_media(arg)
            elif kind == "shell":
                asyncio.create_task(asyncio.create_subprocess_shell(arg))
            elif kind == "none":
                return
            else:
                print("  unbekannte Aktion")
                return
        except KeyError as e:
            print("  unbekannte Taste oder Medientaste:", e)
            return
        if event in PATTERNS:
            display.show(PATTERNS[event], seconds=0.8)

    def on_event(event: str):
        app, chain = profiles()
        action = next((p[event] for p in chain if event in p), None)
        if action:
            perform(app, event, action)
        else:
            print(f"[{app}] {event} (nicht belegt)")

    def on_rotate(delta: int, pressed: bool):
        app, chain = profiles()
        settings = config.get().get("settings", {})
        base = "rotate_pressed" if pressed else "rotate"
        for profile in chain:
            if base in profile:
                kind, _, arg = profile[base].partition(":")
                if kind == "volume":
                    display.show(level(volume.change(delta * 100 / ROTATION_PER_TURN)))
                elif kind == "scroll":
                    send_scroll(delta * settings.get("scroll_speed", 0.5), arg)
                elif kind != "none":
                    print(f"[{app}] {base}: unbekannte Dreh-Aktion {profile[base]}")
                return
            if f"{base}_left" in profile or f"{base}_right" in profile:
                step = settings.get("rotate_step", 300)
                rest = rotation_rest.get(base, 0) + delta
                while abs(rest) >= step:
                    event = f"{base}_right" if rest > 0 else f"{base}_left"
                    rest -= step if rest > 0 else -step
                    if event in profile:
                        perform(app, event, profile[event])
                rotation_rest[base] = rest
                return

    button = ButtonGestures(on_event)

    def on_button(_, data: bytearray):
        button.press() if data[0] else button.release()

    def on_rotation(_, data: bytearray):
        button.rotated()
        on_rotate(int.from_bytes(data[:2], "little", signed=True), button.pressed)

    def on_swipe(_, data: bytearray):
        if data[0] < len(SWIPE_EVENTS):
            on_event(SWIPE_EVENTS[data[0]])

    def on_fly(_, data: bytearray):
        if data[0] in FLY_EVENTS:
            on_event(FLY_EVENTS[data[0]])

    await client.start_notify(BUTTON, on_button)
    await client.start_notify(ROTATION, on_rotation)
    await client.start_notify(SWIPE, on_swipe)
    await client.start_notify(FLY, on_fly)

    # Erst die eigene Verbindungsanimation (Haken) des Nuimo abwarten
    await asyncio.sleep(2)
    display.show(SMILEY, seconds=1)
    while client.is_connected:
        await asyncio.sleep(1)
    print("Verbindung getrennt.")


async def main():
    if not AXIsProcessTrustedWithOptions({kAXTrustedCheckOptionPrompt: True}):
        print("Hinweis: Ohne Freigabe unter Systemeinstellungen › Datenschutz & Sicherheit › Bedienungshilfen")
        print("für dieses Terminal kommen Tastenkürzel und Scrollen nicht an. Danach das Skript neu starten.")
    config = Config()
    config.get()
    volume = Volume()
    while True:
        print("Suche Nuimo … (zum Aufwecken einmal drücken)")
        device = await BleakScanner.find_device_by_name("Nuimo", timeout=30)
        if device is None:
            continue
        try:
            async with BleakClient(device) as client:
                await session(client, config, volume)
        except Exception as e:
            print("Verbindungsfehler:", e)
        await asyncio.sleep(2)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
