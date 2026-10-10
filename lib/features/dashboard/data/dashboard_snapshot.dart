class DashboardSnapshot {
  const DashboardSnapshot({
    required this.zones,
    required this.devices,
    required this.sensors,
    required this.sensorReadings,
    required this.occupancyReadings,
    required this.zoneRisks,
    required this.incidents,
    required this.alerts,
    required this.routes,
    required this.userProfile,
  });

  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> sensors;
  final List<Map<String, dynamic>> sensorReadings;
  final List<Map<String, dynamic>> occupancyReadings;
  final List<Map<String, dynamic>> zoneRisks;
  final List<Map<String, dynamic>> incidents;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> routes;
  final Map<String, dynamic>? userProfile;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) {
      final value = json[key];
      if (value is! List) {
        throw FormatException('Dashboard response is missing "$key".');
      }
      return value
          .map((row) {
            if (row is! Map) {
              throw FormatException(
                'Dashboard response contains an invalid row in "$key".',
              );
            }
            return Map<String, dynamic>.from(row);
          })
          .toList(growable: false);
    }

    final profile = json['user_profile'];
    if (profile != null && profile is! Map) {
      throw const FormatException(
        'Dashboard response contains an invalid user profile.',
      );
    }
    return DashboardSnapshot(
      zones: rows('zones'),
      devices: rows('devices'),
      sensors: rows('sensors'),
      sensorReadings: rows('sensor_readings'),
      occupancyReadings: rows('occupancy_readings'),
      zoneRisks: rows('zone_risks'),
      incidents: rows('incidents'),
      alerts: rows('alerts'),
      routes: rows('routes'),
      userProfile: profile == null ? null : Map<String, dynamic>.from(profile),
    );
  }

  int get peopleInside {
    final latestByZone = <String, int>{};
    for (final reading in occupancyReadings) {
      final zoneId = reading['zone_id']?.toString();
      final count = reading['person_count'];
      if (zoneId != null && count is num) {
        latestByZone.putIfAbsent(zoneId, () => count.toInt());
      }
    }
    return latestByZone.values.fold(0, (total, count) => total + count);
  }

  int get totalCapacity => zones.fold<int>(
    0,
    (total, zone) => total + ((zone['capacity'] as num?)?.toInt() ?? 0),
  );

  Set<String> get activeDangerZoneIds {
    return {
      for (final risk in zoneRisks)
        if (_isHighRisk(risk['risk_level']) && risk['zone_id'] != null)
          risk['zone_id'].toString(),
      for (final incident in incidents)
        if (incident['status'] == 'active' && incident['zone_id'] != null)
          incident['zone_id'].toString(),
    };
  }

  int get dangerZoneCount => activeDangerZoneIds.length;

  static bool _isHighRisk(Object? level) {
    final normalized = level?.toString().toLowerCase();
    return normalized == 'high' || normalized == 'critical';
  }

  int get availableExits => zones.where((zone) {
    if (zone['zone_type'] != 'exit' || zone['is_active'] == false) {
      return false;
    }
    final risk = zoneRisks.where((item) => item['zone_id'] == zone['id']);
    if (risk.isEmpty) return true;
    final level = risk.first['risk_level'];
    return level != 'high' && level != 'critical';
  }).length;

  List<Map<String, dynamic>> get latestOccupancyByZone {
    final latestByZone = <String, Map<String, dynamic>>{};
    for (final reading in occupancyReadings) {
      final zoneId = reading['zone_id']?.toString();
      if (zoneId != null) latestByZone.putIfAbsent(zoneId, () => reading);
    }
    return latestByZone.values.toList(growable: false);
  }

  Map<String, Map<String, dynamic>> get risksByZone {
    return {
      for (final risk in zoneRisks)
        if (risk['zone_id'] != null) risk['zone_id'].toString(): risk,
    };
  }
}
