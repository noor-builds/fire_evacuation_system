import json
import random
import time

import network

from device_config import (
    API_URL,
    DEVICE_API_TOKEN,
    SIMULATE_SENSORS,
    WIFI_PASSWORD,
    WIFI_SSID,
)

try:
    import urequests
except ImportError:
    import requests as urequests

_station_interface = getattr(
    network.WLAN,
    "IF_STA",
    getattr(network, "STA_IF", None),
)
if _station_interface is None:
    raise RuntimeError("This MicroPython build has no Wi-Fi station interface.")
wlan = network.WLAN(_station_interface)


def connect_wifi():
    wlan.active(True)
    if wlan.isconnected():
        print("Wi-Fi connected:", wlan.ifconfig())
        return True

    # Reset the station interface before a new attempt. Calling connect() again
    # while a previous attempt is pending can raise "Wifi Internal Error".
    wlan.active(False)
    time.sleep(1)
    wlan.active(True)
    try:
        wlan.config(reconnects=3)
    except (AttributeError, TypeError):
        pass

    print("Connecting to Wi-Fi:", WIFI_SSID)
    try:
        wlan.connect(WIFI_SSID, WIFI_PASSWORD)
    except OSError as error:
        print("Wi-Fi connect call failed:", error)
        wlan.active(False)
        return False
    for _ in range(30):
        if wlan.isconnected():
            print("Wi-Fi connected:", wlan.ifconfig())
            return True
        time.sleep(1)

    status = wlan.status()
    status_names = {
        getattr(network, "STAT_IDLE", None): "idle",
        getattr(network, "STAT_CONNECTING", None): "connecting",
        getattr(network, "STAT_WRONG_PASSWORD", None): "wrong password",
        getattr(network, "STAT_NO_AP_FOUND", None): "access point not found",
        getattr(network, "STAT_CONNECT_FAIL", None): "connection failed",
    }
    detail = status_names.get(status, str(status))
    wlan.active(False)
    print(
        "Wi-Fi connection failed ({}); will reset and retry next cycle."
        .format(detail)
    )
    return False

if not SIMULATE_SENSORS:
    from machine import ADC, Pin

DEVICE_UID = "ESP 32 A"
NAME = DEVICE_UID
SMOKE_THRESHOLD = 1300
BUZZER_PIN = 25
# GPIO numbers are the labels printed on the ESP32 board.
SMOKE_SENSOR_PINS = {
    "BLOCK A": 32,
    "BLOCK B": 33,
    "BLOCK C": 26,
    "BLOCK D": 27,
}

if SIMULATE_SENSORS:
    buzzer = None
    sensors = {}
else:
    buzzer = Pin(BUZZER_PIN, Pin.OUT)
    buzzer.value(0)
    sensors = {}
    for zone_name, pin_number in SMOKE_SENSOR_PINS.items():
        sensor = ADC(Pin(pin_number))
        sensor.atten(ADC.ATTN_11DB)
        sensors[zone_name] = sensor


def evacuation_gradient_lights(danger_zone, key, light_strip=None):
    if key != DEVICE_UID:
        return None
    if light_strip is None:
        raise ValueError("Pass an initialized NeoPixel strip to this function.")

    led_count = len(light_strip)
    if led_count < 2:
        raise ValueError("The NeoPixel strip must contain at least two LEDs.")

    danger_zones = (
        "BLOCK A",
        "BLOCK B",
        "BLOCK C",
        "BLOCK D",
        "BLOCK E",
        "BLOCK F",
    )
    for index in range(led_count):
        position_ratio = index / (led_count - 1)
        if danger_zone in danger_zones:
            color = (
                int(255 * (1 - position_ratio)),
                int(255 * position_ratio),
                0,
            )
        else:
            color = (0, 255, 0)
        light_strip[index] = color
    light_strip.write()


def get_smoke_desnitya(room, smokeVal, key):
    if key != DEVICE_UID:
        return None
    return room, smokeVal


def potentialFireMsga(room, smokeVal, key):
    if key != DEVICE_UID:
        return None
    return (
        "Fire in room: {}, and smoke density: {}".format(room, smokeVal),
        "Data from: {}".format(NAME),
        "Starting Buzzer sounds...",
    )


def beep_alarm():
    """Pulse the active buzzer so an alarm sounds as separate beeps."""
    if buzzer is None:
        return
    try:
        for _ in range(3):
            buzzer.value(1)
            time.sleep(0.15)
            buzzer.value(0)
            time.sleep(0.15)
    finally:
        buzzer.value(0)


def get_amount_of_people(key):
    if key != DEVICE_UID:
        return None
    return random.randint(1, 430)


def get_amount_of_students(key):
    if key != DEVICE_UID:
        return None
    return random.randint(1, 43)


def post_sensor_readings(readings, occupancy):
    payload = {
        "key": DEVICE_UID,
        "readings": readings,
        "occupancy": occupancy,
        "simulation": SIMULATE_SENSORS,
    }
    headers = {"Content-Type": "application/json"}
    if DEVICE_API_TOKEN:
        headers["X-Device-Token"] = DEVICE_API_TOKEN

    response = urequests.post(
        API_URL,
        data=json.dumps(payload),
        headers=headers,
    )
    try:
        if response.status_code < 200 or response.status_code >= 300:
            detail = response.text[:160]
            raise OSError(
                "Sensor API returned HTTP {}: {}".format(
                    response.status_code, detail
                )
            )
        print("Sensor report stored:", response.text)
    finally:
        response.close()


def read_smoke_sensors():
    """Read smoke sensors independently so one timeout does not stop the loop."""
    readings = {}
    for zone_name, sensor in sensors.items():
        try:
            readings[zone_name] = sensor.read()
        except OSError as first_error:
            print("Smoke sensor read failed for {}: {}".format(zone_name, first_error))
            time.sleep(0.1)
            try:
                readings[zone_name] = sensor.read()
            except OSError as retry_error:
                print(
                    "Smoke sensor retry failed for {}: {}".format(
                        zone_name, retry_error
                    )
                )
    return readings


def run_fire_safety_system(key=DEVICE_UID):
    if key != DEVICE_UID:
        raise ValueError("This device only runs as {}".format(DEVICE_UID))
    connect_wifi()
    while True:
        if SIMULATE_SENSORS:
            readings = {
                name: random.randint(SMOKE_THRESHOLD + 1, 4095)
                for name in SMOKE_SENSOR_PINS
            }
            occupancy = {
                name: random.randint(0, 30) for name in SMOKE_SENSOR_PINS
            }
            print(
                "DEMO DATA ONLY - randomized smoke and occupancy readings"
            )
        else:
            readings = read_smoke_sensors()
            occupancy = {}

        fire_zones = [
            name
            for name, value in readings.items()
            if value < SMOKE_THRESHOLD
        ]
        fire_detected = bool(fire_zones)
        if fire_detected:
            beep_alarm()
        elif buzzer is not None:
            buzzer.value(0)

        print("Smoke readings:", readings)
        for fire_room in fire_zones:
            alert = potentialFireMsga(
                fire_room,
                readings[fire_room],
                DEVICE_UID,
            )
            print("\n".join(alert))
        if not readings and not occupancy:
            print("Sensor report skipped: no valid sensor readings this cycle.")
        elif connect_wifi():
            try:
                post_sensor_readings(readings, occupancy)
            except OSError as error:
                print("Sensor report failed; retrying next cycle:", error)
        time.sleep(3)


run_fire_safety_system()
