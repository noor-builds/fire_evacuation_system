import ast
import os
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError

from backend.api import server


def _firmware_constant(folder: str, name: str):
    firmware_path = Path(__file__).resolve().parents[1] / folder / "main.py"
    module = ast.parse(firmware_path.read_text(encoding="utf-8"))
    assignment = next(
        node
        for node in module.body
        if isinstance(node, ast.Assign)
        and any(
            isinstance(target, ast.Name) and target.id == name
            for target in node.targets
        )
    )
    return ast.literal_eval(assignment.value)


class SensorApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(server.app)
        self.environment = patch.dict(
            os.environ,
            {
                "DEVICE_API_TOKEN": "test-token",
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_SECRET_KEY": "test-secret",
            },
        )
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def test_status_reports_service_and_configuration(self) -> None:
        response = self.client.get("/status")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")
        self.assertTrue(response.json()["dashboard_configured"])
        self.assertTrue(response.json()["device_ingestion_configured"])

    def test_status_is_degraded_without_server_configuration(self) -> None:
        with patch.dict(
            os.environ,
            {
                "DEVICE_API_TOKEN": "",
                "SUPABASE_URL": "",
                "SUPABASE_SECRET_KEY": "",
                "SUPABASE_SERVICE_ROLE_KEY": "",
                "SUPABASE_PUBLISHABLE_KEY": "",
            },
        ):
            response = self.client.get("/status")

        self.assertEqual(response.json()["status"], "degraded")
        self.assertFalse(response.json()["dashboard_configured"])
        self.assertFalse(response.json()["database_configured"])
        self.assertFalse(response.json()["device_ingestion_configured"])

    def test_publishable_key_configures_dashboard_but_not_sensor_writes(self) -> None:
        with patch.dict(
            os.environ,
            {
                "DEVICE_API_TOKEN": "test-token",
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_SECRET_KEY": "",
                "SUPABASE_SERVICE_ROLE_KEY": "",
                "SUPABASE_PUBLISHABLE_KEY": "test-publishable-key",
            },
        ):
            response = self.client.get("/status")

        self.assertTrue(response.json()["dashboard_configured"])
        self.assertFalse(response.json()["database_configured"])
        self.assertFalse(response.json()["sensor_database_configured"])
        self.assertTrue(response.json()["device_ingestion_configured"])

    def test_database_client_uses_configured_server_key(self) -> None:
        base_environment = {
            "SUPABASE_URL": "https://example.supabase.co",
            "SUPABASE_SECRET_KEY": "",
            "SUPABASE_SERVICE_ROLE_KEY": "",
            "SUPABASE_PUBLISHABLE_KEY": "",
        }
        for key_name in (
            "SUPABASE_SECRET_KEY",
            "SUPABASE_SERVICE_ROLE_KEY",
        ):
            with self.subTest(key_name=key_name):
                environment = {**base_environment, key_name: "test-key"}
                with patch.dict(os.environ, environment):
                    server.db.get_client.cache_clear()
                    try:
                        with patch.object(
                            server.db, "create_client", return_value=object()
                        ) as create_client:
                            server.db.get_client()
                        create_client.assert_called_once_with(
                            "https://example.supabase.co", "test-key"
                        )
                        self.assertTrue(server.db.is_configured())
                    finally:
                        server.db.get_client.cache_clear()

    def test_publishable_key_is_not_used_for_server_database_writes(self) -> None:
        with patch.dict(
            os.environ,
            {
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_SECRET_KEY": "",
                "SUPABASE_SERVICE_ROLE_KEY": "",
                "SUPABASE_PUBLISHABLE_KEY": "test-publishable-key",
            },
        ):
            server.db.get_client.cache_clear()
            try:
                self.assertFalse(server.db.is_configured())
                with self.assertRaisesRegex(RuntimeError, "SUPABASE_SECRET_KEY"):
                    server.db.get_client()
            finally:
                server.db.get_client.cache_clear()

    def test_local_browser_preflight_allows_any_development_port(self) -> None:
        app = FastAPI()
        server._add_cors_middleware(app, ["https://dashboard.example"])
        client = TestClient(app)

        response = client.options(
            "/dashboard",
            headers={
                "Origin": "http://localhost:61800",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:61800",
        )

        rejected = client.options(
            "/dashboard",
            headers={
                "Origin": "https://not-allowed.example",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )
        self.assertEqual(rejected.status_code, 400)

    def test_dashboard_requires_a_supabase_bearer_token(self) -> None:
        response = self.client.get("/dashboard")

        self.assertEqual(response.status_code, 401)

    def test_student_count_requires_a_supabase_bearer_token(self) -> None:
        response = self.client.get(
            "/student",
            params={"key": "ESP 32 A", "place": "block"},
        )

        self.assertEqual(response.status_code, 401)

    def test_student_count_forwards_the_signed_in_user_token(self) -> None:
        with patch.object(
            server.db, "get_occupancy_count", return_value=12
        ) as get_count:
            response = self.client.get(
                "/student",
                params={"key": "ESP 32 A", "place": "block"},
                headers={"Authorization": "Bearer signed-in-user-token"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), 12)
        get_count.assert_called_once_with(
            "ESP 32 A", "block", "signed-in-user-token"
        )

    def test_dashboard_allows_browser_authorization_preflight(self) -> None:
        response = self.client.options(
            "/dashboard",
            headers={
                "Origin": "http://localhost:53000",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "*",
        )
        self.assertIn(
            "authorization",
            response.headers["access-control-allow-headers"].lower(),
        )
        self.assertIn("GET", response.headers["access-control-allow-methods"])

    def test_dashboard_forwards_supabase_token_to_database_service(self) -> None:
        snapshot = {
            "zones": [],
            "devices": [],
            "sensors": [],
            "sensor_readings": [],
            "occupancy_readings": [],
            "zone_risks": [],
            "incidents": [],
            "alerts": [],
            "routes": [],
            "user_profile": None,
        }
        with patch.object(
            server.db, "get_dashboard_snapshot", return_value=snapshot
        ) as get_snapshot:
            response = self.client.get(
                "/dashboard",
                headers={"Authorization": "Bearer supabase-access-token"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), snapshot)
        get_snapshot.assert_called_once_with("supabase-access-token")

    def test_dashboard_database_queries_use_the_signed_in_user_token(self) -> None:
        class Query:
            def __init__(self, table: str) -> None:
                self.table = table

            def select(self, *_args, **_kwargs):
                return self

            def eq(self, *_args, **_kwargs):
                return self

            def order(self, *_args, **_kwargs):
                return self

            def limit(self, *_args, **_kwargs):
                return self

            def maybe_single(self):
                return self

            def execute(self):
                if self.table == "users":
                    return None
                return SimpleNamespace(data=[])

        class Client:
            def __init__(self) -> None:
                self.postgrest = Mock()
                self.auth = Mock()
                self.auth.get_user.return_value = SimpleNamespace(
                    user=SimpleNamespace(id="user-id")
                )

            def table(self, name: str) -> Query:
                return Query(name)

        client = Client()
        with patch.dict(
            os.environ,
            {
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_SECRET_KEY": "",
                "SUPABASE_SERVICE_ROLE_KEY": "",
                "SUPABASE_PUBLISHABLE_KEY": "test-publishable-key",
            },
        ), patch.object(
            server.db, "create_client", return_value=client
        ) as create_client:
            snapshot = server.db.get_dashboard_snapshot("signed-in-user-token")

        create_client.assert_called_once_with(
            "https://example.supabase.co", "test-publishable-key"
        )
        client.postgrest.auth.assert_called_once_with("signed-in-user-token")
        client.auth.get_user.assert_called_once_with("signed-in-user-token")
        self.assertEqual(snapshot["zones"], [])
        self.assertEqual(snapshot["user_profile"], None)

    def test_dashboard_reads_legacy_class_incharge_column(self) -> None:
        class Query:
            def __init__(self, table: str) -> None:
                self.table = table
                self.columns = ""

            def select(self, columns: str):
                self.columns = columns
                return self

            def eq(self, *_args, **_kwargs):
                return self

            def order(self, *_args, **_kwargs):
                return self

            def limit(self, *_args, **_kwargs):
                return self

            def maybe_single(self):
                return self

            def execute(self):
                if self.table == "users":
                    if '"class incharge"' not in self.columns:
                        raise APIError(
                            {
                                "message": 'column users.class_incharge does not exist',
                                "code": "42703",
                            }
                        )
                    return SimpleNamespace(
                        data={
                            "id": "user-id",
                            "registered_at": "2026-10-10",
                            "designated_wing": "A",
                            "class_incharge": True,
                            "class": "5A",
                        }
                    )
                return SimpleNamespace(data=[])

        class Client:
            def __init__(self) -> None:
                self.postgrest = Mock()
                self.auth = Mock()
                self.auth.get_user.return_value = SimpleNamespace(
                    user=SimpleNamespace(id="user-id")
                )

            def table(self, name: str) -> Query:
                return Query(name)

        client = Client()
        with patch.dict(
            os.environ,
            {
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_SECRET_KEY": "",
                "SUPABASE_SERVICE_ROLE_KEY": "",
                "SUPABASE_PUBLISHABLE_KEY": "test-publishable-key",
            },
        ), patch.object(server.db, "create_client", return_value=client):
            snapshot = server.db.get_dashboard_snapshot("signed-in-user-token")

        self.assertTrue(snapshot["user_profile"]["class_incharge"])

    def test_sensor_report_is_persisted_and_returns_summary(self) -> None:
        expected = {
            "device_uid": "ESP 32 A",
            "stored_readings": 2,
            "alerts": [],
            "status": "safe",
            "key": "ESP 32 A",
        }
        with patch.object(
            server.db, "persist_sensor_report", return_value={**expected}
        ) as persist:
            response = self.client.post(
                "/sensor_readings",
                headers={"X-Device-Token": "test-token"},
                json={
                    "key": "ESP 32 A",
                    "readings": {"BLOCK A": 210, "BLOCK B": 125},
                    "temp": 24.5,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), expected)
        persist.assert_called_once_with(
            device_uid="ESP 32 A",
            readings={"BLOCK A": 210, "BLOCK B": 125},
            temperature=24.5,
            occupancy={},
        )

    def test_sensor_reports_accept_the_zone_map_used_by_both_boards(self) -> None:
        reports = (
            (
                "ESP 32 A",
                {
                    "BLOCK A": 210,
                    "BLOCK B": 125,
                    "BLOCK C": 90,
                    "BLOCK D": 80,
                },
            ),
            ("ESP 32 B", {"BLOCK E": 175, "BLOCK F": 95}),
        )
        for device_uid, readings in reports:
            with self.subTest(device_uid=device_uid), patch.object(
                server.db, "persist_sensor_report", return_value={"status": "safe"}
            ) as persist:
                response = self.client.post(
                    "/sensor_readings",
                    headers={"X-Device-Token": "test-token"},
                    json={"key": device_uid, "readings": readings},
                )

            self.assertEqual(response.status_code, 200)
            persist.assert_called_once()

    def test_sensor_readings_accept_the_six_documented_block_assignments(self) -> None:
        expected_zones = {
            "ESP 32 A": {"BLOCK A", "BLOCK B", "BLOCK C", "BLOCK D"},
            "ESP 32 B": {"BLOCK E", "BLOCK F"},
        }

        for device_uid, zones in expected_zones.items():
            with self.subTest(device_uid=device_uid):
                report = server.SensorReadings(
                    key=device_uid,
                    readings={zone: 100 for zone in zones},
                )
                self.assertEqual(set(report.readings), zones)

    def test_sensor_thresholds_remain_unchanged(self) -> None:
        self.assertEqual(server.db.SMOKE_THRESHOLD, 1300)
        self.assertEqual(server.db.TEMPERATURE_THRESHOLD, 55)
        self.assertEqual(_firmware_constant("esp32_a", "SMOKE_THRESHOLD"), 1300)
        self.assertEqual(
            _firmware_constant("esp32_a", "TEMPERATURE_THRESHOLD"), 55
        )
        self.assertEqual(_firmware_constant("esp32_b", "SMOKE_THRESHOLD"), 1300)

    def test_firmware_block_maps_match_api_device_assignments(self) -> None:
        firmware_devices = {
            "ESP 32 A": "esp32_a",
            "ESP 32 B": "esp32_b",
        }
        for device_uid, folder in firmware_devices.items():
            with self.subTest(device_uid=device_uid):
                self.assertEqual(
                    set(_firmware_constant(folder, "SMOKE_SENSOR_PINS")),
                    set(server.db.DEVICE_ZONES[device_uid]),
                )

    def test_invalid_zone_is_rejected_before_persistence(self) -> None:
        with patch.object(server.db, "persist_sensor_report") as persist:
            response = self.client.post(
                "/sensor_readings",
                headers={"X-Device-Token": "test-token"},
                json={"key": "ESP 32 A", "readings": {"BLOCK F": 100}},
            )

        self.assertEqual(response.status_code, 422)
        persist.assert_not_called()

    def test_missing_or_invalid_device_token_is_rejected(self) -> None:
        response = self.client.post(
            "/sensor_readings",
            headers={"X-Device-Token": "wrong-token"},
            json={"key": "ESP 32 B", "readings": {"BLOCK E": 100}},
        )

        self.assertEqual(response.status_code, 401)


if __name__ == "__main__":
    unittest.main()
