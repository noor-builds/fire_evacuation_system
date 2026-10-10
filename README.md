# Aegis Grid fire evacuation system

Flutter command center, FastAPI sensor-ingestion service, Supabase/PostgreSQL
database, and MicroPython firmware for two ESP32 sensor units.

## 1. Set up Supabase

Run [`backend/database/schema.sql`](backend/database/schema.sql) once in the
Supabase SQL editor. It creates the application tables, enables authenticated
dashboard access, seeds the sample campus, and adds the ESP32 zones (`BLOCK A`
through `BLOCK F`) and the `Cafeteria` temperature zone.

If the original tables are already installed, run
[`backend/database/seed_esp32_zones.sql`](backend/database/seed_esp32_zones.sql)
once instead; it adds the required zones and authenticated RLS policies, and
renames the legacy `users."class incharge"` column if present.

The SQL schema expects Supabase Auth for sign-in. Create operator accounts in
Supabase Auth. An optional profile row in `public.users` must use the same UUID
as the Auth user. Do not store or use passwords in `public.users`; sign-in is
handled by Supabase Auth.

## 2. Run or deploy the backend

Create `backend/.env` with server-only credentials:

```dotenv
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SECRET_KEY=your-server-only-secret-key
DEVICE_API_TOKEN=replace-with-a-long-random-device-token
HOST=0.0.0.0
PORT=8000
```

Use a Supabase secret key or service-role key only on the server. The public
publishable key is not a replacement: the backend needs server permissions to
write the sensor data allowed by the SQL schema. Never put the server key in
Flutter or ESP32 firmware. From the repository root, install the backend
dependencies and start the API:

```powershell
pip install -r backend\requirements.txt
python -m backend.main
```

Leave this process running while using Flutter. Verify the API responds at
`http://127.0.0.1:8000/status` before launching the web app. The health check
is `GET /status`. ESP32 reports are sent to
`POST /sensor_readings` as JSON with the `X-Device-Token` header:

```json
{
  "key": "ESP 32 A",
  "readings": {
    "BLOCK A": 420,
    "BLOCK B": 510,
    "BLOCK C": 380,
    "BLOCK D": 460
  },
  "temp": 29.5
}
```

`ESP 32 B` may report `BLOCK E` and `BLOCK F`. The server registers devices and
sensors on first contact, writes sensor/occupancy readings and system events,
updates zone risk, and creates or resolves incidents and alerts. Repeated
readings for an already-active incident do not create duplicate alerts.

For Vercel, deploy the repository root. The root [`app.py`](app.py) re-exports
the FastAPI app from `backend/api/server.py`, and the root
[`pyproject.toml`](pyproject.toml) lists the server dependencies and Vercel app
script. In the Vercel project settings, add these Environment Variables for
Production (and Preview if you use preview deployments):

```text
SUPABASE_URL
SUPABASE_SECRET_KEY   (or SUPABASE_SERVICE_ROLE_KEY)
DEVICE_API_TOKEN
CORS_ORIGINS          (optional; comma-separated deployed frontend origins)
```

Set `CORS_ORIGINS` to the exact deployed frontend origin, for example
`https://your-dashboard.vercel.app` (no path or trailing slash). Localhost and
127.0.0.1 development origins are accepted on any port. Redeploy after changing
environment variables, then verify:

```text
https://your-vercel-project.vercel.app/status
```

## 3. Configure the ESP32 boards

In each firmware folder, copy `device_config.example.py` to
`device_config.py` and set the board's Wi-Fi credentials, the chosen backend
URL in `API_URL`, and the same `DEVICE_API_TOKEN` configured on the server.
`device_config.py` is ignored by Git. Flash the matching folder to each board.
The ESP32s need a 2.4 GHz Wi-Fi network and network access to the API URL.
If a real device token was ever saved in a tracked example or committed file,
replace it in Vercel and on both boards before using the system again.

Choose one API connection:

- **Use the deployed Vercel API:** set `API_URL` in both board config files to
  `https://fireevacuationsystem.vercel.app/sensor_readings`. The Vercel backend
  must have `SUPABASE_URL`, `SUPABASE_SECRET_KEY` (or
  `SUPABASE_SERVICE_ROLE_KEY`), and `DEVICE_API_TOKEN` set. Redeploy after
  changing Vercel environment variables.
- **Use a backend running on your computer:** start `python -m backend.main`,
  find your computer's LAN IPv4 address with `ipconfig`, and set each board's
  `API_URL` to `http://<computer-LAN-IP>:8000/sensor_readings` (for example,
  `http://192.168.1.20:8000/sensor_readings`). The computer and ESP32 must be on
  the same Wi-Fi network, and the firewall must allow inbound TCP port 8000.
  Set the Flutter `API_BASE_URL` to `http://127.0.0.1:8000` when running
  Flutter Web on that same computer.

For either option, use the same newly generated random `DEVICE_API_TOKEN` in
the backend environment and both board config files. Copy the example file to
`device_config.py` separately in each board folder, then fill in the board's
Wi-Fi name, password, API URL and token. Never commit `device_config.py` or
paste a token into source control. The app cannot display readings until a
signed-in dashboard user can read Supabase data and the backend can write the
incoming sensor readings.

### Simple wiring map

The pin numbers below are the **GPIO numbers printed on the ESP32 board**, not
the physical pin position along the board edge. Connect every sensor ground to
ESP32 GND. ESP32 GPIO inputs must never receive more than 3.3 V.

| Board | Part | Connect its signal/output pin to |
| --- | --- | --- |
| ESP 32 A | Smoke sensor for BLOCK A | GPIO 32 (analog output/AO) |
| ESP 32 A | Smoke sensor for BLOCK B | GPIO 33 (analog output/AO) |
| ESP 32 A | Smoke sensor for BLOCK C | GPIO 34 (analog output/AO) |
| ESP 32 A | Smoke sensor for BLOCK D | GPIO 35 (analog output/AO) |
| ESP 32 A | DHT22 temperature data | GPIO 23 |
| ESP 32 A or B | Buzzer control signal | GPIO 25 |
| ESP 32 B | Smoke sensor for BLOCK E | GPIO 32 (analog output/AO) |
| ESP 32 B | Smoke sensor for BLOCK F | GPIO 33 (analog output/AO) |

Power each sensor according to its module's specification, but make sure its
output to an ESP32 GPIO stays at or below 3.3 V. GPIO 34 and GPIO 35 are
input-only and are used only for smoke sensor readings here. Use a transistor
or driver for a buzzer that needs more current than an ESP32 GPIO can supply.
The firmware reports ADC counts from 0 to 4095, not calibrated ppm. The
`SMOKE_THRESHOLD = 1300` value is a starting point; check clean-air readings
and calibrate it for the exact sensor/module before relying on alarms.

## 4. Run Flutter

The app uses Supabase Auth for sign-in, then sends the signed-in session's
access token to `GET /dashboard`. The backend verifies that token with Supabase
Auth and returns the dashboard snapshot from the same tables that the ESP32
ingestion API writes. The Flutter app refreshes that snapshot every ten seconds
and also provides a manual refresh. The publishable key can be used for
authenticated dashboard reads; ESP32 ingestion writes require a server-only
`SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY` on the backend. A
`SUPABASE_PUBLISHABLE_KEY` alone cannot authorize those writes.

The data path is: smoke sensors and (on ESP 32 A) the DHT22 send readings to
`POST /sensor_readings`; the backend checks `X-Device-Token` and writes rows to
`devices`, `sensors`, `sensor_readings`, `zone_risk`, `incidents`, `alerts`,
and `system_events` in Supabase. The dashboard loads those rows from
`GET /dashboard` using the signed-in user's Supabase session. Keep the SQL
schema's BLOCK A through BLOCK F and Cafeteria zones installed; the backend
uses those exact names.

The campus map reads high/critical zone risk and active incidents from this live
dashboard snapshot. Sensor readings update the risk and automatically create or
resolve incidents; the map has no manual declare/clear control. Acknowledging an
alert only marks that notification as seen and does not mark an active fire safe.
Only database zones explicitly matched to a position on the schematic are colored
on the map. Other active zones are listed above the map as unmapped sensor alerts
so they are visible without being assigned an unverified location.

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

The default API origin is `http://127.0.0.1:8000`; the app appends `/dashboard`
for dashboard requests. For the Android emulator, set
`--dart-define=API_BASE_URL=http://10.0.2.2:8000`; for a physical phone, use
the computer's reachable LAN address. To use a deployed backend, set
`API_BASE_URL` to its origin. The API handles browser `OPTIONS` preflight requests for the
`Authorization` header. For a deployed Flutter Web origin, set the backend
`CORS_ORIGINS` environment variable to its exact origin (scheme and host,
including port if applicable; multiple origins can be comma-separated), then
restart/redeploy the backend. Use HTTPS for deployed frontend and backend
origins. When deploying Flutter Web, override the local default with the deployed API
origin at build time:

```powershell
flutter build web --release `
  --dart-define=API_BASE_URL=https://your-api-service.example.com `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Use the deployed FastAPI service origin (not a Flutter frontend URL) as
`API_BASE_URL`; do not include `/dashboard` because the app adds that path.
Install the MicroPython `urequests` package on both boards if it is not already
present in their firmware.

## 5. Verify

```powershell
python -m unittest discover -s backend/tests
flutter analyze
flutter test
```
