import json
import random
import time

import neopixel #A module in machine

import dht
import urequests
from machine import ADC, Pin

import boot
from device_config import API_URL, DEVICE_API_TOKEN

DEVICE_UID = "ESP 32 A"
NAME = DEVICE_UID
SMOKE_THRESHOLD = 1300
TEMPERATURE_THRESHOLD = 55
BUZZER_PIN = 25
TEMPERATURE_SENSOR_PIN = 23
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

temperature_sensor = dht.DHT22(Pin(TEMPERATURE_SENSOR_PIN))


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


def get_cafe_temp(temp, key):
    if key != DEVICE_UID:
        return None
    return "cafeteria temprature", temp


def potentialFireMsga(room, smokeVal, key):
    if key != DEVICE_UID:
        return None
    return (
        "Fire in room: {}, and smoke density: {}".format(room, smokeVal),
        "Data from: {}".format(NAME),
        "Starting Buzzer sounds...",
    )


def SuddenTemperatureIncrease(temp, key):
    if key != DEVICE_UID:
        return None
    return (
        "Sudden increase in temperature in cafe! Current: {}°C. "
        "Start evacuation!".format(temp)
    )


def get_amount_of_people(key):
    if key != DEVICE_UID:
        return None
    return random.randint(1, 430)


def get_amount_of_students(key):
    if key != DEVICE_UID:
        return None
    return random.randint(1, 43)


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


def run_fire_safety_system(key=DEVICE_UID):
    if key != DEVICE_UID:
        raise ValueError("This device only runs as {}".format(DEVICE_UID))
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
        if any(value > SMOKE_THRESHOLD for value in readings.values()):
            highest_room = max(readings, key=readings.get)
            alert = potentialFireMsga(
                highest_room,
                readings[highest_room],
                DEVICE_UID,
            )
            print("\n".join(alert))
        if temperature is not None and temperature > TEMPERATURE_THRESHOLD:
            print(SuddenTemperatureIncrease(temperature, DEVICE_UID))
        if boot.connect_wifi():
            try:
                post_sensor_readings(readings, temperature)
            except OSError as error:
                print("Sensor report failed; retrying next cycle:", error)
        time.sleep(3)


run_fire_safety_system()
