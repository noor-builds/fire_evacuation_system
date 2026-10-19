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
      expect(
        tester.getSize(find.byType(Card).first).width,
        lessThanOrEqualTo(size.width - 40),
      );
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

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Acknowledge alert'));
    await tester.pump();
    expect(acknowledgedId, 'alert-1');
  });

  testWidgets('overview shows real readings and no occupancy as unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardOverview(
            selectedSection: 0,
            snapshot: _snapshot(
              sensorReadings: [
                {
                  'zone_id': 'zone-a',
                  'value': 735,
                  'unit': 'ADC count',
                  'recorded_at': '2026-10-10T07:00:00Z',
                },
              ],
            ),
            isLoading: false,
            databaseError: null,
            apiError: null,
            apiStatus: const {'status': 'ok'},
            onRefresh: () {},
            onAcknowledgeAlert: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('—'), findsAtLeastNWidgets(1));
    expect(find.text('No occupancy readings'), findsOneWidget);
    expect(find.textContaining('BLOCK A · 735 ADC count'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('occupancy lists all six blocks and identifies estimates', (
    tester,
  ) async {
    final zones = List.generate(6, (index) {
      final block = String.fromCharCode('A'.codeUnitAt(0) + index);
      return {
        'id': 'zone-$block',
        'name': 'BLOCK $block',
        'zone_type': 'classroom',
        'capacity': 40,
      };
    });
    final snapshot = DashboardSnapshot(
      zones: zones,
      devices: const [],
      sensors: const [],
      sensorReadings: const [],
      occupancyReadings: [
        {
          'zone_id': 'zone-A',
          'person_count': 12,
          'source': 'estimated',
          'recorded_at': '2026-10-10T07:00:00Z',
        },
      ],
      zoneRisks: const [],
      incidents: const [],
      alerts: const [],
      routes: const [],
      userProfile: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardOverview(
            selectedSection: 3,
            snapshot: snapshot,
            isLoading: false,
            databaseError: null,
            apiError: null,
            apiStatus: const {'status': 'ok'},
            onRefresh: () {},
            onAcknowledgeAlert: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    for (final block in ['A', 'B', 'C', 'D', 'E', 'F']) {
      expect(find.text('BLOCK $block'), findsOneWidget);
    }
    expect(
      find.textContaining('12 children · Random demo estimate'),
      findsOneWidget,
    );
    expect(find.text('No occupancy reading received'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard sections transition when navigation changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardOverview(
            selectedSection: 0,
            snapshot: _snapshot(),
            isLoading: false,
            databaseError: null,
            apiError: null,
            apiStatus: const {'status': 'ok'},
            onRefresh: () {},
            onAcknowledgeAlert: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Command center'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardOverview(
            selectedSection: 1,
            snapshot: _snapshot(),
            isLoading: false,
            databaseError: null,
            apiError: null,
            apiStatus: const {'status': 'ok'},
            onRefresh: () {},
            onAcknowledgeAlert: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Live map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

DashboardSnapshot _snapshot({
  bool activeBlockA = false,
  bool activeBlockB = false,
  List<Map<String, dynamic>> alerts = const [],
  List<Map<String, dynamic>> sensorReadings = const [],
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
    sensorReadings: sensorReadings,
    occupancyReadings: const [],
    zoneRisks: zoneRisks,
    incidents: incidents,
    alerts: alerts,
    routes: const [],
    userProfile: null,
  );
}
