import json
import time

import dht
import urequests
from machine import ADC, Pin

import boot
from device_config import API_URL, DEVICE_API_TOKEN

DEVICE_UID = "ESP 32 A"
SMOKE_THRESHOLD = 1300
TEMPERATURE_THRESHOLD = 55
BUZZER_PIN = 25
TEMPERATURE_SENSOR_PIN = 23
# GPIO numbers are the labels printed on the ESP32 board.
SMOKE_SENSOR_PINS = {
    "BLOCK A": 32,
    "BLOCK B": 33,
    "BLOCK C": 34,
    "BLOCK D": 35,
}

buzzer = Pin(BUZZER_PIN, Pin.OUT)
buzzer.value(0)
sensors = {}
for zone_name, pin_number in SMOKE_SENSOR_PINS.items():
    sensor = ADC(Pin(pin_number))
    sensor.atten(ADC.ATTN_11DB)
    sensors[zone_name] = sensor

temperature_sensor = dht.DHT22(Pin(TEMPERATURE_SENSOR_PIN))


def post_sensor_readings(readings, temperature):
    payload = {"key": DEVICE_UID, "readings": readings}
    if temperature is not None:
        payload["temp"] = temperature
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
        temperature = None
        try:
            temperature_sensor.measure()
            temperature = temperature_sensor.temperature()
        except OSError as error:
            print("Cafeteria temperature sensor read failed:", error)

        fire_detected = any(
            value > SMOKE_THRESHOLD for value in readings.values()
        ) or (temperature is not None and temperature > TEMPERATURE_THRESHOLD)
        buzzer.value(1 if fire_detected else 0)

        print("Smoke readings:", readings)
        print("Cafeteria temperature:", temperature)
        if boot.connect_wifi():
            try:
                post_sensor_readings(readings, temperature)
            except OSError as error:
                print("Sensor report failed; retrying next cycle:", error)
        time.sleep(3)


run_fire_safety_system()
