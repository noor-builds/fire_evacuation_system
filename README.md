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
once instead; it adds the required zones and authenticated RLS policies.

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

Use a Supabase secret/service-role key only on the server. Never put it in
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
script. Set `SUPABASE_URL`, `SUPABASE_SECRET_KEY` or
`SUPABASE_SERVICE_ROLE_KEY`, `DEVICE_API_TOKEN`, and optionally
`CORS_ORIGINS` in the Vercel project environment, then verify:

```text
https://your-vercel-project.vercel.app/status
```

## 3. Configure the ESP32 boards

In each firmware folder, copy `device_config.example.py` to
`device_config.py` and set the board's Wi-Fi credentials, the server's LAN
address in `API_URL`, and the same `DEVICE_API_TOKEN` configured on the server.
`device_config.py` is ignored by Git. Flash the matching folder to each board.
The ESP32s need network access to the computer running FastAPI.

## 4. Run Flutter

The app uses Supabase Auth for sign-in, then sends the signed-in session's
access token to `GET /dashboard`. The backend verifies that token with Supabase
Auth and returns the dashboard snapshot from the same tables that the ESP32
ingestion API writes. The Flutter app refreshes that snapshot every ten seconds
and also provides a manual refresh. The Supabase publishable key stays in the
Flutter app; the server-only Supabase key stays on the backend.

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
