import 'package:fire_evacuation_app/features/dashboard/data/dashboard_snapshot.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_route_card.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_school_map_card.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_stat_card.dart';
import 'package:flutter/material.dart';

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.selectedSection,
    required this.snapshot,
    required this.isLoading,
    required this.databaseError,
    required this.apiError,
    required this.apiStatus,
    required this.onRefresh,
    required this.onAcknowledgeAlert,
  });

  final int selectedSection;
  final DashboardSnapshot? snapshot;
  final bool isLoading;
  final String? databaseError;
  final String? apiError;
  final Map<String, dynamic>? apiStatus;
  final VoidCallback onRefresh;
  final Future<void> Function(String alertId) onAcknowledgeAlert;

  static const _sections = [
    ('Command center', 'Safety overview of the school'),
    ('Live map', 'Campus map and current zone risk'),
    ('Sensors', 'Monitor devices and the latest sensor data'),
    ('Occupancy', 'People counts reported by each zone'),
    ('Alerts', 'Active alerts and incident reports'),
    ('Settings', 'Service connection and account status'),
  ];

  @override
  Widget build(BuildContext context) {
    final safeIndex = selectedSection.clamp(0, _sections.length - 1);
    final (title, subtitle) = _sections[safeIndex];
    final databaseConnected = snapshot != null && databaseError == null;
    final apiConnected =
        apiStatus?['dashboard_configured'] == true ||
        (apiStatus?['dashboard_configured'] == null &&
            apiStatus?['status'] == 'ok');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A9AAD),
                      fontSize: 13,
                    ),
                  ),
                ],
              );
              final status = _ConnectionBadge(
                label: isLoading
                    ? 'CONNECTING'
                    : databaseConnected && apiConnected
                    ? 'SYSTEM ONLINE'
                    : 'CHECK CONNECTIONS',
                color: isLoading
                    ? const Color(0xFFF6C453)
                    : databaseConnected && apiConnected
                    ? const Color(0xFF55C987)
                    : const Color(0xFFF6C453),
              );

              if (constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 12), status],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  status,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (databaseError != null || apiError != null) ...[
            _ConnectionErrors(
              databaseError: databaseError,
              apiError: apiError,
              onRetry: onRefresh,
            ),
            const SizedBox(height: 16),
          ],
          if (snapshot == null && isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (snapshot == null)
            _EmptyState(
              title: 'Dashboard data unavailable',
              message: databaseError ?? 'Refresh to try loading the dashboard.',
              onRefresh: onRefresh,
            )
          else
            switch (safeIndex) {
              0 => _OverviewContent(
                snapshot: snapshot!,
                onAcknowledgeAlert: onAcknowledgeAlert,
              ),
              1 => _LiveMapContent(snapshot: snapshot!),
              2 => _SensorsContent(snapshot: snapshot!),
              3 => _OccupancyContent(snapshot: snapshot!),
              4 => _AlertsContent(
                snapshot: snapshot!,
                onAcknowledgeAlert: onAcknowledgeAlert,
              ),
              _ => _SettingsContent(
                snapshot: snapshot!,
                apiConnected: apiConnected,
                apiError: apiError,
              ),
            },
        ],
      ),
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.snapshot,
    required this.onAcknowledgeAlert,
  });

  final DashboardSnapshot snapshot;
  final Future<void> Function(String alertId) onAcknowledgeAlert;

  @override
  Widget build(BuildContext context) {
    final occupancy = snapshot.peopleInside;
    final capacity = snapshot.totalCapacity;
    final occupancyPercent = capacity == 0
        ? 0
        : (occupancy / capacity * 100).round().clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth < 600 ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth < 600 ? 1.45 : 1.65,
            children: [
              DashboardStatCard(
                label: 'PEOPLE INSIDE',
                value: '$occupancy',
                description: 'Latest count per zone',
                icon: Icons.groups_rounded,
                color: const Color(0xFF5CB5F2),
              ),
              DashboardStatCard(
                label: 'OCCUPANCY',
                value: capacity == 0 ? '—' : '$occupancyPercent%',
                description: capacity == 0 ? 'No capacity set' : 'Of capacity',
                icon: Icons.analytics_rounded,
                color: const Color(0xFF55C987),
              ),
              DashboardStatCard(
                label: 'DANGER ZONES',
                value: '${snapshot.dangerZoneCount}',
                description: 'High or critical risk',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFE63946),
              ),
              DashboardStatCard(
                label: 'SAFE EXITS',
                value: '${snapshot.availableExits}',
                description: 'Available exits',
                icon: Icons.exit_to_app_rounded,
                color: const Color(0xFF5CB5F2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  CampusMapHazardApp(snapshot: snapshot),
                  const SizedBox(height: 16),
                  DashboardRouteCard(
                    routes: snapshot.routes,
                    zones: snapshot.zones,
                  ),
                  const SizedBox(height: 16),
                  _AlertsPanel(
                    alerts: snapshot.alerts,
                    onAcknowledgeAlert: onAcknowledgeAlert,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: CampusMapHazardApp(snapshot: snapshot),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      DashboardRouteCard(
                        routes: snapshot.routes,
                        zones: snapshot.zones,
                      ),
                      const SizedBox(height: 16),
                      _AlertsPanel(
                        alerts: snapshot.alerts,
                        onAcknowledgeAlert: onAcknowledgeAlert,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LiveMapContent extends StatelessWidget {
  const _LiveMapContent({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CampusMapHazardApp(snapshot: snapshot),
      const SizedBox(height: 16),
      DashboardRouteCard(routes: snapshot.routes, zones: snapshot.zones),
    ],
  );
}

class _SensorsContent extends StatelessWidget {
  const _SensorsContent({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _DataPanel(
        title: 'REGISTERED SENSORS',
        emptyMessage: 'No sensors are registered in the sensors table.',
        rows: snapshot.sensors.map((sensor) {
          final status = sensor['status']?.toString() ?? 'unknown';
          return _DataRow(
            title:
                sensor['sensor_name']?.toString() ??
                sensor['sensor_type']?.toString() ??
                'Unnamed sensor',
            subtitle:
                '${sensor['sensor_type'] ?? 'unknown'} · '
                '${sensor['device_id'] ?? 'No device'}',
            badge: status.toUpperCase(),
            color: status == 'active'
                ? const Color(0xFF55C987)
                : const Color(0xFFF6C453),
            icon: Icons.sensors_rounded,
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      _DataPanel(
        title: 'REGISTERED DEVICES',
        emptyMessage: 'No ESP32 devices are registered in the devices table.',
        rows: snapshot.devices.map((device) {
          final status = device['status']?.toString() ?? 'unknown';
          return _DataRow(
            title:
                device['device_name']?.toString() ??
                device['device_uid']?.toString() ??
                'Unnamed device',
            subtitle: device['device_uid']?.toString() ?? 'No device ID',
            badge: status.toUpperCase(),
            color: status == 'online'
                ? const Color(0xFF55C987)
                : const Color(0xFFF6C453),
            icon: Icons.sensors_rounded,
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      _DataPanel(
        title: 'LATEST SENSOR READINGS',
        emptyMessage: 'No sensor readings have been recorded yet.',
        rows: snapshot.sensorReadings.take(20).map((reading) {
          final value = reading['value']?.toString() ?? '—';
          final unit = reading['unit']?.toString() ?? '';
          return _DataRow(
            title: '$value $unit'.trim(),
            subtitle:
                '${reading['sensor_id'] ?? 'Unknown sensor'} · ${_time(reading['recorded_at'])}',
            icon: Icons.multiline_chart_rounded,
          );
        }).toList(),
      ),
    ],
  );
}

class _OccupancyContent extends StatelessWidget {
  const _OccupancyContent({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) => _DataPanel(
    title: 'LATEST OCCUPANCY BY ZONE',
    emptyMessage: 'No occupancy readings have been recorded yet.',
    rows: snapshot.latestOccupancyByZone.map((reading) {
      final zone = snapshot.zones.where(
        (item) => item['id'] == reading['zone_id'],
      );
      final zoneName = zone.isEmpty ? 'Unknown zone' : zone.first['name'];
      return _DataRow(
        title: '$zoneName',
        subtitle:
            '${reading['person_count'] ?? 0} people · '
            '${_time(reading['recorded_at'])}',
        icon: Icons.groups_rounded,
      );
    }).toList(),
  );
}

class _AlertsContent extends StatelessWidget {
  const _AlertsContent({
    required this.snapshot,
    required this.onAcknowledgeAlert,
  });

  final DashboardSnapshot snapshot;
  final Future<void> Function(String alertId) onAcknowledgeAlert;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _AlertsPanel(
        alerts: snapshot.alerts,
        onAcknowledgeAlert: onAcknowledgeAlert,
      ),
      const SizedBox(height: 16),
      _DataPanel(
        title: 'ACTIVE INCIDENTS',
        emptyMessage: 'There are no active incidents.',
        rows: snapshot.incidents.map((incident) {
          final severity = incident['severity']?.toString() ?? 'low';
          return _DataRow(
            title: incident['incident_type']?.toString() ?? 'Incident',
            subtitle:
                incident['description']?.toString() ??
                _time(incident['detected_at']),
            badge: severity.toUpperCase(),
            color: severity == 'critical' || severity == 'high'
                ? const Color(0xFFE63946)
                : const Color(0xFFF6C453),
            icon: Icons.warning_amber_rounded,
          );
        }).toList(),
      ),
    ],
  );
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.snapshot,
    required this.apiConnected,
    this.apiError,
  });

  final DashboardSnapshot snapshot;
  final bool apiConnected;
  final String? apiError;

  @override
  Widget build(BuildContext context) {
    return _DataPanel(
      title: 'CONNECTED SERVICES',
      emptyMessage: '',
      rows: [
        _DataRow(
          title: 'FastAPI sensor server',
          subtitle: apiError ?? 'GET /status',
          badge: apiConnected ? 'ONLINE' : 'OFFLINE',
          color: apiConnected
              ? const Color(0xFF55C987)
              : const Color(0xFFF6C453),
          icon: Icons.cloud_outlined,
        ),
        _DataRow(
          title: 'Account profile',
          subtitle: snapshot.userProfile == null
              ? 'No matching row in public.users'
              : _profileSummary(snapshot.userProfile!),
          icon: Icons.account_circle_outlined,
        ),
        const _DataRow(
          title: 'Supabase',
          subtitle: 'Auth and campus safety database',
          icon: Icons.storage_rounded,
        ),
      ],
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.alerts, required this.onAcknowledgeAlert});

  final List<Map<String, dynamic>> alerts;
  final Future<void> Function(String alertId) onAcknowledgeAlert;

  @override
  Widget build(BuildContext context) => _DataPanel(
    title: 'ACTIVE ALERTS',
    emptyMessage: 'No unacknowledged alerts.',
    rows: alerts.take(8).map((alert) {
      final severity = alert['severity']?.toString() ?? 'info';
      return _DataRow(
        title: alert['title']?.toString() ?? 'Alert',
        subtitle: alert['message']?.toString() ?? 'No alert details.',
        badge: severity.toUpperCase(),
        color: severity == 'critical' || severity == 'high'
            ? const Color(0xFFE63946)
            : severity == 'warning'
            ? const Color(0xFFF6C453)
            : const Color(0xFF5CB5F2),
        icon: Icons.notifications_active_outlined,
        trailing: alert['id'] == null
            ? null
            : IconButton(
                tooltip: 'Acknowledge alert',
                onPressed: () => onAcknowledgeAlert(alert['id'].toString()),
                icon: const Icon(Icons.check_circle_outline),
              ),
      );
    }).toList(),
  );
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.title,
    required this.emptyMessage,
    required this.rows,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            )
          else
            ...rows,
        ],
      ),
    ),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.color,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: color ?? Theme.of(context).colorScheme.primary,
            size: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Text(
              badge!,
              style: TextStyle(
                color: color ?? muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ConnectionErrors extends StatelessWidget {
  const _ConnectionErrors({
    this.databaseError,
    this.apiError,
    required this.onRetry,
  });

  final String? databaseError;
  final String? apiError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF38202A),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (databaseError != null)
            Text(
              'Dashboard API: $databaseError',
              style: const TextStyle(fontSize: 12),
            ),
          if (apiError != null) ...[
            if (databaseError != null) const SizedBox(height: 6),
            Text(
              'Fire server: $apiError',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.onRefresh,
  });

  final String title;
  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ),
  );
}

String _time(Object? timestamp) {
  if (timestamp == null) return 'Time unavailable';
  final dateTime = DateTime.tryParse(timestamp.toString())?.toLocal();
  if (dateTime == null) return 'Time unavailable';
  return '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

String _profileSummary(Map<String, dynamic> profile) {
  final details = <String>[];
  if (profile['designated_wing'] != null) {
    details.add(profile['designated_wing'].toString());
  }
  if (profile['class'] != null) {
    details.add('Class ${profile['class']}');
  }
  if (profile['class_incharge'] == true) details.add('Class incharge');
  return details.isEmpty ? 'Profile loaded' : details.join(' · ');
}
