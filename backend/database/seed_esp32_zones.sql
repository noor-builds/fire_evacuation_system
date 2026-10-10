-- Apply this only when the original Aegis Grid schema is already installed.
-- New installations get these zones from schema.sql.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'class incharge'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'class_incharge'
    ) THEN
        ALTER TABLE public.users
            RENAME COLUMN "class incharge" TO class_incharge;
    END IF;
END
$$;

INSERT INTO zones (name, zone_type, floor)
SELECT source.name, source.zone_type, 0
FROM (VALUES
    ('BLOCK A', 'other'),
    ('BLOCK B', 'other'),
    ('BLOCK C', 'other'),
    ('BLOCK D', 'other'),
    ('BLOCK E', 'other'),
    ('BLOCK F', 'other'),
    ('Cafeteria', 'cafeteria')
) AS source(name, zone_type)
WHERE NOT EXISTS (
    SELECT 1 FROM zones existing WHERE existing.name = source.name
);

INSERT INTO zone_risk (zone_id)
SELECT z.id
FROM zones AS z
WHERE z.name IN (
    'BLOCK A', 'BLOCK B', 'BLOCK C', 'BLOCK D',
    'BLOCK E', 'BLOCK F', 'Cafeteria'
)
ON CONFLICT (zone_id) DO NOTHING;

CREATE UNIQUE INDEX IF NOT EXISTS idx_zones_name_unique ON zones(name);

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
