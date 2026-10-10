import math
import os
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from postgrest.exceptions import APIError
from supabase import Client, create_client

load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")
load_dotenv()

SMOKE_THRESHOLD = 1300
TEMPERATURE_THRESHOLD = 55
DEVICE_ZONES = {
    "ESP 32 A": ("BLOCK A", "BLOCK B", "BLOCK C", "BLOCK D"),
    "ESP 32 B": ("BLOCK E", "BLOCK F"),
}
CAFETERIA_ZONE = "Cafeteria"


def _server_key() -> str | None:
    return os.environ.get("SUPABASE_SECRET_KEY") or os.environ.get(
        "SUPABASE_SERVICE_ROLE_KEY"
    )


def is_configured() -> bool:
    return bool(os.environ.get("SUPABASE_URL") and _server_key())


def _create_client(*, allow_publishable_key: bool = False) -> Client:
    url = os.environ.get("SUPABASE_URL")
    key = _server_key()
    if not key and allow_publishable_key:
        key = os.environ.get("SUPABASE_PUBLISHABLE_KEY")
    if not url or not key:
        raise RuntimeError(
            "Set SUPABASE_URL and SUPABASE_SECRET_KEY "
            "(or SUPABASE_SERVICE_ROLE_KEY) for the backend."
        )
    return create_client(url, key)


@lru_cache(maxsize=1)
def get_client() -> Client:
    return _create_client()


def _zone_ids(names: set[str]) -> dict[str, str]:
    if not names:
        return {}
    rows = (
        get_client()
        .table("zones")
        .select("id,name")
        .in_("name", sorted(names))
        .execute()
        .data
    )
    found = {row["name"]: row["id"] for row in rows}
    missing = names - found.keys()
    if missing:
        raise LookupError(
            "Missing zones in Supabase: " + ", ".join(sorted(missing))
        )
    return found


def _get_or_create_device(device_uid: str, zone_id: str) -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    data = (
        get_client()
        .table("devices")
        .upsert(
            {
                "device_uid": device_uid,
                "device_name": f"Fire sensor {device_uid}",
                "zone_id": zone_id,
                "status": "online",
                "last_seen_at": now,
                "updated_at": now,
            },
            on_conflict="device_uid",
        )
        .select("id")
        .single()
        .execute()
        .data
    )
    if not data:
        raise RuntimeError(f"Supabase returned no device row for {device_uid}.")
    return data


def _get_or_create_sensor(
    device_id: str,
    zone_id: str,
    sensor_type: str,
    sensor_name: str,
    unit: str,
) -> str:
    client = get_client()
    existing = (
        client.table("sensors")
        .select("id")
        .eq("device_id", device_id)
        .eq("zone_id", zone_id)
        .eq("sensor_type", sensor_type)
        .eq("sensor_name", sensor_name)
        .maybe_single()
        .execute()
        .data
    )
    if existing:
        return existing["id"]

    data = (
        client.table("sensors")
        .insert(
            {
                "device_id": device_id,
                "zone_id": zone_id,
                "sensor_type": sensor_type,
                "sensor_name": sensor_name,
                "unit": unit,
            }
        )
        .select("id")
        .single()
        .execute()
        .data
    )
    return data["id"]


def _score(value: float, threshold: float) -> float:
    return round(min(100.0, max(0.0, value / threshold * 100)), 2)


def _risk_level(score: float) -> str:
    if score < 30:
        return "safe"
    if score < 60:
        return "caution"
    if score < 85:
        return "high"
    return "critical"


def _update_zone_risk(
    zone_id: str,
    *,
    smoke_score: float | None = None,
    temperature_score: float | None = None,
) -> None:
    client = get_client()
    previous = (
        client.table("zone_risk")
        .select("smoke_score,temperature_score")
        .eq("zone_id", zone_id)
        .maybe_single()
        .execute()
        .data
    ) or {}
    smoke = (
        smoke_score
        if smoke_score is not None
        else float(previous.get("smoke_score") or 0)
    )
    temperature = (
        temperature_score
        if temperature_score is not None
        else float(previous.get("temperature_score") or 0)
    )
    score = max(smoke, temperature)
    client.table("zone_risk").upsert(
        {
            "zone_id": zone_id,
            "risk_score": score,
            "risk_level": _risk_level(score),
            "smoke_score": smoke,
            "temperature_score": temperature,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        },
        on_conflict="zone_id",
    ).execute()


def _record_or_resolve_incident(
    *,
    zone_id: str,
    incident_type: str,
    active: bool,
    severity: str = "high",
    description: str,
) -> str | None:
    client = get_client()
    existing = (
        client.table("incidents")
        .select("id")
        .eq("zone_id", zone_id)
        .eq("incident_type", incident_type)
        .eq("status", "active")
        .maybe_single()
        .execute()
        .data
    )

    if not active:
        if existing:
            client.table("incidents").update(
                {
                    "status": "resolved",
                    "resolved_at": datetime.now(timezone.utc).isoformat(),
                }
            ).eq("id", existing["id"]).execute()
        return None
    if existing:
        return existing["id"]

    incident = (
        client.table("incidents")
        .insert(
            {
                "zone_id": zone_id,
                "incident_type": incident_type,
                "severity": severity,
                "description": description,
            }
        )
        .select("id")
        .single()
        .execute()
        .data
    )
    incident_id = incident["id"]
    client.table("alerts").insert(
        {
            "zone_id": zone_id,
            "incident_id": incident_id,
            "title": f"{incident_type.replace('_', ' ').title()} detected",
            "message": description,
            "severity": "critical" if severity == "critical" else "high",
        }
    ).execute()
    return incident_id


def persist_sensor_report(
    device_uid: str,
    readings: dict[str, float],
    temperature: float | None = None,
    occupancy: dict[str, int] | None = None,
) -> dict[str, Any]:
    if device_uid not in DEVICE_ZONES:
        raise ValueError("Unknown ESP32 device.")
    if not readings and temperature is None and not occupancy:
        raise ValueError("A report must contain at least one reading.")

    allowed_zones = set(DEVICE_ZONES[device_uid])
    unknown = set(readings) - allowed_zones
    if occupancy:
        unknown |= set(occupancy) - allowed_zones
    if unknown:
        raise LookupError(
            f"{device_uid} cannot report zones: " + ", ".join(sorted(unknown))
        )
    if any(not math.isfinite(value) or value < 0 for value in readings.values()):
        raise ValueError("Smoke readings must be finite and zero or greater.")
    if temperature is not None and not math.isfinite(temperature):
        raise ValueError("Temperature must be a finite number.")
    if occupancy and any(count < 0 for count in occupancy.values()):
        raise ValueError("Occupancy counts must be zero or greater.")

    zone_names = set(readings)
    if occupancy:
        zone_names |= set(occupancy)
    primary_zone = DEVICE_ZONES[device_uid][0]
    zone_names.add(primary_zone)
    if temperature is not None:
        if device_uid != "ESP 32 A":
            raise ValueError("Cafeteria temperature is supported by ESP 32 A only.")
        zone_names.add(CAFETERIA_ZONE)
    zones = _zone_ids(zone_names)
    device = _get_or_create_device(device_uid, zones[primary_zone])
    client = get_client()
    recorded = 0
    alerts: list[dict[str, str]] = []

    for zone_name, value in readings.items():
        zone_id = zones[zone_name]
        sensor_id = _get_or_create_sensor(
            device["id"],
            zone_id,
            "smoke",
            f"Smoke sensor {zone_name}",
            "ppm",
        )
        client.table("sensor_readings").insert(
            {
                "sensor_id": sensor_id,
                "zone_id": zone_id,
                "value": value,
                "unit": "ppm",
            }
        ).execute()
        recorded += 1

        score = _score(value, SMOKE_THRESHOLD)
        _update_zone_risk(zone_id, smoke_score=score)
        active = value > SMOKE_THRESHOLD
        severity = "critical" if value >= SMOKE_THRESHOLD * 2 else "high"
        description = f"Smoke reading in {zone_name}: {value:g} ppm."
        if _record_or_resolve_incident(
            zone_id=zone_id,
            incident_type="smoke",
            active=active,
            severity=severity,
            description=description,
        ):
            alerts.append({"zone": zone_name, "type": "smoke"})

    if temperature is not None:
        zone_id = zones[CAFETERIA_ZONE]
        sensor_id = _get_or_create_sensor(
            device["id"],
            zone_id,
            "temperature",
            "Cafeteria temperature sensor",
            "°C",
        )
        client.table("sensor_readings").insert(
            {
                "sensor_id": sensor_id,
                "zone_id": zone_id,
                "value": temperature,
                "unit": "°C",
            }
        ).execute()
        recorded += 1

        score = _score(temperature, TEMPERATURE_THRESHOLD)
        _update_zone_risk(zone_id, temperature_score=score)
        active = temperature > TEMPERATURE_THRESHOLD
        severity = "critical" if temperature >= 70 else "high"
        description = f"Cafeteria temperature: {temperature:g} °C."
        if _record_or_resolve_incident(
            zone_id=zone_id,
            incident_type="high_temperature",
            active=active,
            severity=severity,
            description=description,
        ):
            alerts.append({"zone": CAFETERIA_ZONE, "type": "high_temperature"})

    for zone_name, person_count in (occupancy or {}).items():
        client.table("occupancy_readings").insert(
            {
                "zone_id": zones[zone_name],
                "person_count": person_count,
                "source": "sensor",
            }
        ).execute()
        recorded += 1

    client.table("system_events").insert(
        {
            "event_type": "sensor_report_received",
            "source": device_uid,
            "device_id": device["id"],
            "payload": {
                "readings": readings,
                "temperature": temperature,
                "occupancy": occupancy or {},
            },
        }
    ).execute()
    return {
        "device_uid": device_uid,
        "stored_readings": recorded,
        "alerts": alerts,
        "status": "fire_detected" if alerts else "safe",
    }


def get_occupancy_count(device_uid: str, place: str) -> int:
    if device_uid not in DEVICE_ZONES:
        raise ValueError("Unknown ESP32 device.")
    if place not in {"class", "block"}:
        raise ValueError("place must be class or block.")

    client = get_client()
    zones = (
        client.table("zones")
        .select("id,zone_type")
        .in_("name", list(DEVICE_ZONES[device_uid]))
        .execute()
        .data
    )
    if not zones:
        raise LookupError(f"No zones are configured for {device_uid}.")
    if place == "class":
        zones = [zone for zone in zones if zone["zone_type"] == "classroom"]
    zone_ids = [zone["id"] for zone in zones]
    if not zone_ids:
        return 0

    readings = (
        client.table("occupancy_readings")
        .select("zone_id,person_count")
        .in_("zone_id", zone_ids)
        .order("recorded_at", desc=True)
        .limit(1000)
        .execute()
        .data
    )
    latest_by_zone: dict[str, int] = {}
    for reading in readings:
        latest_by_zone.setdefault(reading["zone_id"], reading["person_count"])
    return sum(latest_by_zone.values())


def get_dashboard_snapshot(access_token: str) -> dict[str, Any]:
    client = _create_client(allow_publishable_key=True)
    client.postgrest.auth(access_token)
    user = client.auth.get_user(access_token)
    if user is None or user.user is None:
        raise PermissionError("The Supabase access token is invalid or expired.")

    profile_query = (
        client.table("users")
        .select("id,registered_at,designated_wing,class_incharge,class")
        .eq("id", user.user.id)
        .maybe_single()
    )
    try:
        profile_response = profile_query.execute()
        profile = profile_response.data if profile_response is not None else None
    except APIError as error:
        if error.code != "42703":
            raise
        profile_response = (
            client.table("users")
            .select(
                'id,registered_at,designated_wing,'
                'class_incharge:"class incharge",class'
            )
            .eq("id", user.user.id)
            .maybe_single()
            .execute()
        )
        profile = profile_response.data if profile_response is not None else None
    return {
        "zones": client.table("zones").select("*").order("name").execute().data,
        "devices": (
            client.table("devices").select("*").order("device_name").execute().data
        ),
        "sensors": (
            client.table("sensors").select("*").order("sensor_name").execute().data
        ),
        "sensor_readings": (
            client.table("sensor_readings")
            .select("*")
            .order("recorded_at", desc=True)
            .limit(100)
            .execute()
            .data
        ),
        "occupancy_readings": (
            client.table("occupancy_readings")
            .select("*")
            .order("recorded_at", desc=True)
            .limit(100)
            .execute()
            .data
        ),
        "zone_risks": client.table("zone_risk").select("*").execute().data,
        "incidents": (
            client.table("incidents")
            .select("*")
            .eq("status", "active")
            .order("detected_at", desc=True)
            .limit(50)
            .execute()
            .data
        ),
        "alerts": (
            client.table("alerts")
            .select("*")
            .eq("is_acknowledged", False)
            .order("created_at", desc=True)
            .limit(50)
            .execute()
            .data
        ),
        "routes": (
            client.table("evacuation_routes")
            .select("*")
            .eq("is_recommended", True)
            .order("calculated_at", desc=True)
            .limit(10)
            .execute()
            .data
        ),
        "user_profile": profile,
    }
