-- AEGIS GRID — PostgreSQL schema
-- Run once in the Supabase SQL editor before starting the backend.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    zone_type VARCHAR(30) NOT NULL
        CHECK (zone_type IN (
            'classroom', 'corridor', 'exit', 'staircase', 'cafeteria',
            'office', 'assembly_point', 'other'
        )),
    floor INTEGER NOT NULL DEFAULT 0,
    x NUMERIC(10, 2),
    y NUMERIC(10, 2),
    capacity INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
    id UUID PRIMARY KEY,
    registered_at DATE NOT NULL DEFAULT CURRENT_DATE,
    password TEXT,
    designated_wing TEXT,
    class_incharge BOOLEAN DEFAULT FALSE,
    class TEXT
);

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_uid VARCHAR(100) UNIQUE NOT NULL,
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    device_name VARCHAR(100),
    firmware_version VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'offline'
        CHECK (status IN ('online', 'offline', 'warning', 'error')),
    last_seen_at TIMESTAMPTZ,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE sensors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    sensor_type VARCHAR(40) NOT NULL
        CHECK (sensor_type IN (
            'smoke', 'temperature', 'humidity', 'occupancy', 'door',
            'air_quality', 'flame', 'other'
        )),
    sensor_name VARCHAR(100),
    unit VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'error')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE sensor_readings (
    id BIGSERIAL PRIMARY KEY,
    sensor_id UUID REFERENCES sensors(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    value NUMERIC(12, 4) NOT NULL,
    unit VARCHAR(20),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE occupancy_readings (
    id BIGSERIAL PRIMARY KEY,
    zone_id UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    person_count INTEGER NOT NULL CHECK (person_count >= 0),
    confidence NUMERIC(5, 2)
        CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 100)),
    source VARCHAR(30) NOT NULL DEFAULT 'sensor'
        CHECK (source IN ('sensor', 'thermal_camera', 'manual', 'estimated')),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE zone_risk (
    zone_id UUID PRIMARY KEY REFERENCES zones(id) ON DELETE CASCADE,
    risk_score NUMERIC(5, 2) NOT NULL DEFAULT 0
        CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_level VARCHAR(20) NOT NULL DEFAULT 'safe'
        CHECK (risk_level IN ('safe', 'caution', 'high', 'critical')),
    smoke_score NUMERIC(5, 2) DEFAULT 0,
    temperature_score NUMERIC(5, 2) DEFAULT 0,
    crowd_score NUMERIC(5, 2) DEFAULT 0,
    accessibility_score NUMERIC(5, 2) DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE graph_edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_zone_id UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    to_zone_id UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    distance NUMERIC(10, 2) NOT NULL CHECK (distance >= 0),
    base_risk NUMERIC(5, 2) NOT NULL DEFAULT 0
        CHECK (base_risk >= 0 AND base_risk <= 100),
    is_accessible BOOLEAN NOT NULL DEFAULT TRUE,
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(from_zone_id, to_zone_id)
);

CREATE TABLE incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    incident_type VARCHAR(40) NOT NULL
        CHECK (incident_type IN (
            'fire', 'smoke', 'high_temperature', 'blocked_exit',
            'crowding', 'sensor_failure', 'other'
        )),
    severity VARCHAR(20) NOT NULL DEFAULT 'low'
        CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'resolved', 'false_alarm')),
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE TABLE evacuation_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_zone_id UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    destination_zone_id UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    distance NUMERIC(10, 2) NOT NULL,
    risk_score NUMERIC(10, 2) NOT NULL,
    total_cost NUMERIC(10, 2) NOT NULL,
    is_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE evacuation_route_steps (
    id BIGSERIAL PRIMARY KEY,
    route_id UUID NOT NULL REFERENCES evacuation_routes(id) ON DELETE CASCADE,
    zone_id UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    step_order INTEGER NOT NULL,
    UNIQUE(route_id, step_order)
);

CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    incident_id UUID REFERENCES incidents(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'info'
        CHECK (severity IN ('info', 'warning', 'high', 'critical')),
    is_acknowledged BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ
);

CREATE TABLE device_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    command_type VARCHAR(40) NOT NULL
        CHECK (command_type IN (
            'alarm_on', 'alarm_off', 'led_red', 'led_green',
            'display_message', 'evacuation_mode', 'reset', 'other'
        )),
    payload JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'executed', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    executed_at TIMESTAMPTZ
);

CREATE TABLE system_events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    source VARCHAR(50),
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sensor_readings_zone_time
    ON sensor_readings(zone_id, recorded_at DESC);
CREATE INDEX idx_occupancy_zone_time
    ON occupancy_readings(zone_id, recorded_at DESC);
CREATE INDEX idx_incidents_status ON incidents(status);
CREATE INDEX idx_alerts_active ON alerts(is_acknowledged, created_at DESC);
CREATE INDEX idx_system_events_time ON system_events(created_at DESC);

ALTER TABLE zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensors ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE occupancy_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE zone_risk ENABLE ROW LEVEL SECURITY;
ALTER TABLE graph_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE evacuation_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE evacuation_route_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_events ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON zones, devices, sensors, sensor_readings, occupancy_readings,
    zone_risk, graph_edges, incidents, evacuation_routes,
    evacuation_route_steps, alerts, device_commands, system_events
    TO authenticated;

CREATE POLICY authenticated_read_zones ON zones
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_devices ON devices
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_sensors ON sensors
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_sensor_readings ON sensor_readings
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_occupancy_readings ON occupancy_readings
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_zone_risk ON zone_risk
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_graph_edges ON graph_edges
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_incidents ON incidents
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_evacuation_routes ON evacuation_routes
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_route_steps ON evacuation_route_steps
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_alerts ON alerts
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_device_commands ON device_commands
    FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_system_events ON system_events
    FOR SELECT TO authenticated USING (true);

REVOKE ALL ON users FROM anon, authenticated;
GRANT SELECT (id, registered_at, designated_wing, class_incharge, class)
    ON users TO authenticated;
GRANT INSERT (id, registered_at, designated_wing, class_incharge, class)
    ON users TO authenticated;
GRANT UPDATE (designated_wing, class_incharge, class)
    ON users TO authenticated;
CREATE POLICY users_read_own_profile ON users
    FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY users_insert_own_profile ON users
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY users_update_own_profile ON users
    FOR UPDATE TO authenticated
    USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

REVOKE UPDATE ON alerts FROM anon, authenticated;
GRANT UPDATE (is_acknowledged, acknowledged_at) ON alerts TO authenticated;
CREATE POLICY authenticated_acknowledge_alerts ON alerts
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

INSERT INTO zones (name, zone_type, floor, x, y, capacity) VALUES
    ('C1', 'classroom', 0, 100, 100, 40),
    ('C2', 'classroom', 0, 300, 100, 40),
    ('C3', 'classroom', 0, 500, 100, 40),
    ('Corridor A', 'corridor', 0, 200, 200, NULL),
    ('Corridor B', 'corridor', 0, 400, 200, NULL),
    ('Exit A', 'exit', 0, 100, 400, NULL),
    ('Exit B', 'exit', 0, 500, 400, NULL),
    ('Assembly Point A', 'assembly_point', 0, 100, 600, NULL),
    ('BLOCK A', 'classroom', 0, NULL, NULL, 40),
    ('BLOCK B', 'classroom', 0, NULL, NULL, 40),
    ('BLOCK C', 'classroom', 0, NULL, NULL, 40),
    ('BLOCK D', 'classroom', 0, NULL, NULL, 40),
    ('BLOCK E', 'classroom', 0, NULL, NULL, 40),
    ('BLOCK F', 'classroom', 0, NULL, NULL, 40),
    ('Cafeteria', 'cafeteria', 0, NULL, NULL, NULL)
ON CONFLICT (name) DO NOTHING;

INSERT INTO zone_risk (zone_id)
SELECT id FROM zones
ON CONFLICT (zone_id) DO NOTHING;

INSERT INTO occupancy_readings (zone_id, person_count, source)
SELECT
    z.id,
    floor(random() * COALESCE(NULLIF(z.capacity, 0), 40))::integer + 1,
    'estimated'
FROM zones AS z
WHERE z.name IN (
    'BLOCK A', 'BLOCK B', 'BLOCK C', 'BLOCK D', 'BLOCK E', 'BLOCK F'
)
AND NOT EXISTS (
    SELECT 1
    FROM occupancy_readings AS readings
    WHERE readings.zone_id = z.id
);
