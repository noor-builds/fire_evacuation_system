import hmac
import math
import os
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator
from supabase_auth.errors import AuthApiError

from backend.database import db

ESP32_A = "ESP 32 A"
ESP32_B = "ESP 32 B"
DEVICE_ZONES = db.DEVICE_ZONES
LOCAL_WEB_ORIGIN_REGEX = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

app = FastAPI(
    title="Aegis Grid API",
    description="Sensor ingestion and health endpoints for the fire evacuation dashboard.",
    version="1.0.0",
)

cors_origins = [
    origin.strip()
    for origin in os.environ.get("CORS_ORIGINS", "*").split(",")
    if origin.strip()
]


def _add_cors_middleware(application: FastAPI, allowed_origins: list[str]) -> None:
    application.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_origin_regex=LOCAL_WEB_ORIGIN_REGEX,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Device-Token"],
        max_age=600,
    )


_add_cors_middleware(app, cors_origins)


class SensorReadings(BaseModel):
    key: str
    readings: dict[str, float] = Field(default_factory=dict)
    temp: float | None = Field(default=None, ge=-40, le=125)
    occupancy: dict[str, int] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_report(self) -> "SensorReadings":
        if self.key not in DEVICE_ZONES:
            raise ValueError("key must be ESP 32 A or ESP 32 B.")
        allowed_zones = set(DEVICE_ZONES[self.key])
        invalid_zones = (set(self.readings) | set(self.occupancy)) - allowed_zones
        if invalid_zones:
            raise ValueError(
                f"{self.key} cannot report zones: {', '.join(sorted(invalid_zones))}"
            )
        if self.key == ESP32_B and self.temp is not None:
            raise ValueError("Cafeteria temperature is supported by ESP 32 A only.")
        if not self.readings and self.temp is None and not self.occupancy:
            raise ValueError("At least one sensor reading is required.")
        if any(
            not math.isfinite(value) or value < 0
            for value in self.readings.values()
        ):
            raise ValueError("Smoke readings must be finite and zero or greater.")
        if self.temp is not None and not math.isfinite(self.temp):
            raise ValueError("Temperature must be a finite number.")
        if any(count < 0 for count in self.occupancy.values()):
            raise ValueError("Occupancy counts must be zero or greater.")
        return self


def require_device_token(
    x_device_token: Annotated[str | None, Header()] = None,
) -> None:
    expected = os.environ.get("DEVICE_API_TOKEN")
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="DEVICE_API_TOKEN is not configured on the server.",
        )
    if not x_device_token or not hmac.compare_digest(x_device_token, expected):
        raise HTTPException(status_code=401, detail="Invalid device token.")


def _persist_report(payload: SensorReadings) -> dict:
    try:
        return db.persist_sensor_report(
            device_uid=payload.key,
            readings=payload.readings,
            temperature=payload.temp,
            occupancy=payload.occupancy,
        )
    except LookupError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.get("/")
async def read_root() -> dict[str, str]:
    return {"message": "Welcome to the Aegis Grid API."}


@app.get("/status")
async def read_status() -> dict[str, object]:
    database_configured = db.is_configured()
    device_ingestion_configured = bool(os.environ.get("DEVICE_API_TOKEN"))
    return {
        "status": (
            "ok" if database_configured and device_ingestion_configured else "degraded"
        ),
        "database_configured": database_configured,
        "device_ingestion_configured": device_ingestion_configured,
    }


@app.get("/student")
def get_student_count(key: str, place: str) -> int:
    try:
        return db.get_occupancy_count(key, place)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except LookupError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.get("/dashboard")
def get_dashboard(
    authorization: Annotated[str | None, Header()] = None,
) -> dict:
    if authorization is None or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=401,
            detail="A Supabase access token is required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = authorization[7:].strip()
    if not access_token:
        raise HTTPException(
            status_code=401,
            detail="A Supabase access token is required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        return db.get_dashboard_snapshot(access_token)
    except AuthApiError as error:
        raise HTTPException(
            status_code=401,
            detail="The Supabase access token is invalid or expired.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error
    except PermissionError as error:
        raise HTTPException(status_code=401, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.post("/sensor_readings", dependencies=[Depends(require_device_token)])
def process_sensor_readings(payload: SensorReadings) -> dict:
    result = _persist_report(payload)
    result["key"] = payload.key
    return result


@app.post("/smoke_density", dependencies=[Depends(require_device_token)])
def get_smoke_density(key: str, room: str, smokeVal: float) -> dict:
    payload = SensorReadings(key=key, readings={room: smokeVal})
    return _persist_report(payload)


@app.post("/cafe_temperature", dependencies=[Depends(require_device_token)])
def get_cafe_temperature(key: str, temp: float) -> dict:
    payload = SensorReadings(key=key, temp=temp)
    return _persist_report(payload)


@app.post("/potential_fire", dependencies=[Depends(require_device_token)])
def potential_fire(
    key: str, room: str, smokeVal: float, temp: float | None = None
) -> dict:
    payload = SensorReadings(
        key=key,
        readings={room: smokeVal},
        temp=temp,
    )
    return _persist_report(payload)


@app.post("/evacuation_lights", dependencies=[Depends(require_device_token)])
def get_evacuation_light_directive(key: str, danger_zone: str) -> dict:
    if key != ESP32_A:
        raise HTTPException(
            status_code=422,
            detail="Evacuation lights are available from ESP 32 A only.",
        )
    if danger_zone not in DEVICE_ZONES[ESP32_A]:
        raise HTTPException(status_code=422, detail="Unknown danger_zone.")
    return {
        "key": key,
        "danger_zone": danger_zone,
        "effect": "red_to_green_gradient",
        "active": True,
    }
