import json
import random
import time

import urequests
from machine import ADC, Pin

import boot
from device_config import API_URL, DEVICE_API_TOKEN

DEVICE_UID = "ESP 32 B"
NAME = DEVICE_UID
SMOKE_THRESHOLD = 1300
BUZZER_PIN = 25
# GPIO numbers are the labels printed on the ESP32 board.
SMOKE_SENSOR_PINS = {
    "BLOCK E": 32,
    "BLOCK F": 33,
}

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


def post_sensor_readings(readings):
    payload = {"key": DEVICE_UID, "readings": readings}
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
    boot.connect_wifi()
    while True:
        readings = {name: sensor.read() for name, sensor in sensors.items()}
        fire_detected = any(
            value > SMOKE_THRESHOLD for value in readings.values()
        )
        buzzer.value(1 if fire_detected else 0)

        print("Smoke readings:", readings)
        if fire_detected:
            highest_room = max(readings, key=readings.get)
            alert = potentialFireMsg(
                highest_room,
                readings[highest_room],
                DEVICE_UID,
            )
            print("\n".join(alert))
        if boot.connect_wifi():
            try:
                post_sensor_readings(readings)
            except OSError as error:
                print("Sensor report failed; retrying next cycle:", error)
        time.sleep(3)


run_fire_safety_system()
