import json
import time

import urequests
from machine import ADC, Pin

import boot
from device_config import API_URL, DEVICE_API_TOKEN

DEVICE_UID = "ESP 32 B"
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
            raise OSError("Sensor API returned HTTP {}".format(response.status_code))
        print("Sensor report stored:", response.text)
    finally:
        response.close()


def run_fire_safety_system():
    boot.connect_wifi()
    while True:
        readings = {name: sensor.read() for name, sensor in sensors.items()}
        fire_detected = any(
            value > SMOKE_THRESHOLD for value in readings.values()
        )
        buzzer.value(1 if fire_detected else 0)

        print("Smoke readings:", readings)
        if boot.connect_wifi():
            try:
                post_sensor_readings(readings)
            except OSError as error:
                print("Sensor report failed; retrying next cycle:", error)
        time.sleep(3)


run_fire_safety_system()
