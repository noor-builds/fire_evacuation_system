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

DEVICE_UID = "ESP 32 B"
NAME = DEVICE_UID
SMOKE_THRESHOLD = 100
BUZZER_PIN = 25
# GPIO numbers are the labels printed on the ESP32 board.
SMOKE_SENSOR_PINS = {
    "BLOCK E": 32,
    "BLOCK F": 33,
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


def potentialFireMsg(room, smokeVal, key):
    if key != DEVICE_UID:
        return None
    return (
        "Fire in room: {}, and smoke density: {}".format(room, smokeVal),
        "Data from: {}".format(NAME),
        "Starting Buzzer sounds...",
    )


def get_smoke_desnity(room, smokeVal, key):
    if key != DEVICE_UID:
        return None
    return room, smokeVal


def get_amount_of_peopleb(key):
    if key != DEVICE_UID:
        return None
    return random.randint(1, 430)


def get_amount_of_heads_in_class(key):
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


def run_fire_safety_system(key=DEVICE_UID):
    if key != DEVICE_UID:
        raise ValueError("This device only runs as {}".format(DEVICE_UID))
    connect_wifi()
    while True:
        if SIMULATE_SENSORS:
            readings = {
                name: random.randint(120, 900) for name in SMOKE_SENSOR_PINS
            }
            occupancy = {
                name: random.randint(0, 30) for name in SMOKE_SENSOR_PINS
            }
            print("DEMO DATA ONLY - randomized smoke and occupancy readings")
        else:
            readings = {name: sensor.read() for name, sensor in sensors.items()}
            occupancy = {}
        fire_detected = any(
            value < SMOKE_THRESHOLD for value in readings.values()
        )
        if buzzer is not None:
            buzzer.value(1 if fire_detected else 0)

        print("Smoke readings:", readings)
        if fire_detected:
            highest_room = min(readings, key=readings.get)
            alert = potentialFireMsg(
                highest_room,
                readings[highest_room],
                DEVICE_UID,
            )
            print("\n".join(alert))
        if connect_wifi():
            try:
                post_sensor_readings(readings, occupancy)
            except OSError as error:
                print("Sensor report failed; retrying next cycle:", error)
        time.sleep(3)


run_fire_safety_system()
