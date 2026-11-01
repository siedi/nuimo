# /// script
# requires-python = ">=3.11"
# dependencies = ["bleak"]
# ///
"""Connects to a Senic Nuimo, prints every input and shows it on the LED matrix."""

import asyncio

from bleak import BleakClient, BleakScanner

SENSOR = "f29b15{}-cb19-40f3-be5c-7241ecb82fd2"
BUTTON = SENSOR.format("29")
ROTATION = SENSOR.format("28")
SWIPE = SENSOR.format("27")
FLY = SENSOR.format("26")
LED_MATRIX = "f29b1524-cb19-40f3-be5c-7241ecb82fd1"
BATTERY = "00002a19-0000-1000-8000-00805f9b34fb"

LONG_PRESS = 0.4  # seconds to hold until a press counts as long
DOUBLE_GAP = 0.35  # seconds to wait for a second press
ROTATION_PER_TURN = 2650  # approximate rotation value of one full turn

SWIPE_NAMES = [
    "swipe left", "swipe right", "swipe up", "swipe down",
    "touch left", "touch right", "touch top", "touch bottom",
    "longtouch left", "longtouch right", "longtouch top", "longtouch bottom",
]
FLY_NAMES = {0: "fly left", 1: "fly right", 4: "fly up/down"}


def grid(pattern: str) -> list[bool]:
    """Convert a 9x9 pattern of '*' (on) and '.' (off) into 81 pixels."""
    return [c == "*" for c in pattern if c in ".*"]


def rotate(pixels: list[bool]) -> list[bool]:
    """Rotate a pattern 90° clockwise."""
    return [pixels[(8 - col) * 9 + row] for row in range(9) for col in range(9)]


SMILEY = grid("""
.........
..*...*..
..*...*..
.........
.*.....*.
..*...*..
...***...
.........
.........
""")
CIRCLE = grid("""
.........
...***...
..*****..
.*******.
.*******.
.*******.
..*****..
...***...
.........
""")
TWO_DOTS = grid("""
.........
.........
.........
.**...**.
.**...**.
.........
.........
.........
.........
""")
ARROW_LEFT = grid("""
.........
...*.....
..*......
.*.......
*********
.*.......
..*......
...*.....
.........
""")
ARROW_UP = rotate(ARROW_LEFT)
ARROW_RIGHT = rotate(ARROW_UP)
ARROW_DOWN = rotate(ARROW_RIGHT)
DOT_LEFT = grid("""
.........
.........
.........
**.......
**.......
**.......
.........
.........
.........
""")
DOT_TOP = rotate(DOT_LEFT)
DOT_RIGHT = rotate(DOT_TOP)
DOT_BOTTOM = rotate(DOT_RIGHT)

SWIPE_PATTERNS = [
    ARROW_LEFT, ARROW_RIGHT, ARROW_UP, ARROW_DOWN,
    DOT_LEFT, DOT_RIGHT, DOT_TOP, DOT_BOTTOM,
    DOT_LEFT, DOT_RIGHT, DOT_TOP, DOT_BOTTOM,
]
FLY_PATTERNS = {0: ARROW_LEFT, 1: ARROW_RIGHT}


def level(percent: float) -> list[bool]:
    """Level 0–100 % as a fill gauge, row by row from bottom to top."""
    pixels = [False] * 81
    for k in range(round(percent / 100 * 81)):
        pixels[(8 - k // 9) * 9 + k % 9] = True
    return pixels


def matrix_bytes(pixels: list[bool], brightness: int = 255, seconds: float = 3.0) -> bytes:
    """81 pixels as 13 bytes: 81 pixel bits, then brightness, then display time in 1/10 s."""
    data = bytearray(11)
    for i, on in enumerate(pixels):
        if on:
            data[i // 8] |= 1 << (i % 8)
    return bytes(data) + bytes([brightness, min(255, int(seconds * 10))])


class Display:
    """Writes images to the LED matrix; if they arrive faster than BLE can deliver, the newest wins."""

    def __init__(self, client: BleakClient):
        self.client = client
        self.frame = None
        self.ready = asyncio.Event()
        self.task = asyncio.create_task(self._run())

    def show(self, pixels: list[bool], seconds: float = 1.5):
        self.frame = matrix_bytes(pixels, seconds=seconds)
        self.ready.set()

    async def _run(self):
        while True:
            await self.ready.wait()
            self.ready.clear()
            frame, self.frame = self.frame, None
            try:
                await self.client.write_gatt_char(LED_MATRIX, frame, response=True)
            except Exception as e:
                print("LED error:", e)


class ButtonGestures:
    """Turns press/release into short, long and double presses.

    A press that was held long or used for rotating does not count as a click.
    """

    def __init__(self, emit):
        self.emit = emit
        self.loop = asyncio.get_running_loop()
        self.pressed = False
        self.consumed = False
        self.clicks = 0
        self.long_timer = None
        self.click_timer = None

    def press(self):
        self.pressed = True
        self.consumed = False
        if self.click_timer:
            self.click_timer.cancel()
            self.click_timer = None
        self.long_timer = self.loop.call_later(LONG_PRESS, self._long)

    def release(self):
        self.pressed = False
        self.long_timer.cancel()
        if self.consumed:
            return
        self.clicks += 1
        if self.clicks == 2:
            self.clicks = 0
            self.emit("double_press")
        else:
            self.click_timer = self.loop.call_later(DOUBLE_GAP, self._single)

    def rotated(self):
        if self.pressed and not self.consumed:
            self._consume()

    def _long(self):
        self._consume()
        self.emit("long_press")

    def _single(self):
        self.clicks = 0
        self.click_timer = None
        self.emit("press")

    def _consume(self):
        self.consumed = True
        self.clicks = 0
        self.long_timer.cancel()


async def main():
    print("Searching for Nuimo …")
    device = await BleakScanner.find_device_by_name("Nuimo", timeout=15)
    if device is None:
        print("No Nuimo found. Is it awake (press once)?")
        return

    async with BleakClient(device) as client:
        battery = (await client.read_gatt_char(BATTERY))[0]
        print(f"Connected. Battery: {battery} %")
        display = Display(client)
        # Wait for the Nuimo's own connection animation (check mark) first
        await asyncio.sleep(2)
        display.show(SMILEY)

        gesture_patterns = {"press": SMILEY, "long_press": CIRCLE, "double_press": TWO_DOTS}
        gesture_labels = {"press": "short press", "long_press": "long press", "double_press": "double press"}
        value = 50.0

        def on_gesture(name: str):
            print(gesture_labels[name])
            display.show(gesture_patterns[name])

        button = ButtonGestures(on_gesture)

        def on_button(_, data: bytearray):
            button.press() if data[0] else button.release()

        def on_rotation(_, data: bytearray):
            nonlocal value
            button.rotated()
            delta = int.from_bytes(data[:2], "little", signed=True)
            value = max(0.0, min(100.0, value + delta * 100 / ROTATION_PER_TURN))
            print("rotation (pressed)" if button.pressed else "rotation", delta, f"→ {value:.0f} %")
            display.show(level(value))

        def on_swipe(_, data: bytearray):
            code = data[0]
            print(SWIPE_NAMES[code] if code < len(SWIPE_NAMES) else f"swipe/touch {code}")
            if code < len(SWIPE_PATTERNS):
                display.show(SWIPE_PATTERNS[code], seconds=0.8)

        def on_fly(_, data: bytearray):
            print(FLY_NAMES.get(data[0], f"fly {data[0]}"), "distance", data[1])
            if data[0] in FLY_PATTERNS:
                display.show(FLY_PATTERNS[data[0]], seconds=0.8)

        await client.start_notify(BUTTON, on_button)
        await client.start_notify(ROTATION, on_rotation)
        await client.start_notify(SWIPE, on_swipe)
        await client.start_notify(FLY, on_fly)

        print("Turn, press, swipe … (Ctrl-C quits)")
        while client.is_connected:
            await asyncio.sleep(1)
        print("Disconnected.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
