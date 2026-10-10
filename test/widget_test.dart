import 'package:fire_evacuation_app/features/dashboard/data/dashboard_snapshot.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_overview.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_school_map_card.dart';
import 'package:fire_evacuation_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(390, 844), Size(768, 820), Size(1280, 800)]) {
    testWidgets('login screen renders at ${size.width}px', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MyApp());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('campus map uses the requested map and opens live details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CampusMapHazardApp(snapshot: _snapshot()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final gate = find.text('Gate No. 1');
    expect(gate, findsOneWidget);
    await tester.tap(gate);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Primary vehicular entrance and security booth.'),
      findsOneWidget,
    );
    expect(find.text('Declare Danger Zone'), findsNothing);
    expect(find.text('Clear Hazard (Mark Safe)'), findsNothing);
    expect(
      find.text('No active sensor alert is reported for this zone.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('acknowledged alerts do not clear active sensor map hazards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CampusMapHazardApp(
              snapshot: _snapshot(
                activeBlockA: true,
                alerts: [
                  {
                    'id': 'alert-1',
                    'is_acknowledged': true,
                    'zone_id': 'zone-a',
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Block-A'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('HAZARD DETECTED'), findsOneWidget);
    expect(
      find.textContaining('A sensor alert is active in this zone.'),
      findsOneWidget,
    );
    expect(find.text('Clear Hazard (Mark Safe)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmapped active sensor zones remain visible as map alerts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampusMapHazardApp(snapshot: _snapshot(activeBlockB: true)),
        ),
      ),
    );

    expect(
      find.textContaining(
        'Active sensor alert not placed on this map: BLOCK B',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('alert acknowledge button calls the dashboard action', (
    tester,
  ) async {
    String? acknowledgedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardOverview(
            selectedSection: 4,
            snapshot: _snapshot(
              alerts: [
                {
                  'id': 'alert-1',
                  'title': 'Smoke detected',
                  'severity': 'high',
                },
              ],
            ),
            isLoading: false,
            databaseError: null,
            apiError: null,
            apiStatus: const {'status': 'ok'},
            onRefresh: () {},
            onAcknowledgeAlert: (id) async => acknowledgedId = id,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Acknowledge alert'));
    await tester.pump();
    expect(acknowledgedId, 'alert-1');
  });
}

DashboardSnapshot _snapshot({
  bool activeBlockA = false,
  bool activeBlockB = false,
  List<Map<String, dynamic>> alerts = const [],
}) {
  final zones = [
    {'id': 'zone-a', 'name': 'BLOCK A'},
    {'id': 'zone-b', 'name': 'BLOCK B'},
  ];
  final zoneRisks = <Map<String, dynamic>>[];
  final incidents = <Map<String, dynamic>>[];
  if (activeBlockA) {
    zoneRisks.add({'zone_id': 'zone-a', 'risk_level': 'high'});
    incidents.add({'zone_id': 'zone-a', 'status': 'active'});
  }
  if (activeBlockB) {
    zoneRisks.add({'zone_id': 'zone-b', 'risk_level': 'critical'});
    incidents.add({'zone_id': 'zone-b', 'status': 'active'});
  }
  return DashboardSnapshot(
    zones: zones,
    devices: const [],
    sensors: const [],
    sensorReadings: const [],
    occupancyReadings: const [],
    zoneRisks: zoneRisks,
    incidents: incidents,
    alerts: alerts,
    routes: const [],
    userProfile: null,
  );
}
