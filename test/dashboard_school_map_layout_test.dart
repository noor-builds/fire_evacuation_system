import 'package:fire_evacuation_app/features/dashboard/data/dashboard_snapshot.dart';
import 'package:fire_evacuation_app/features/dashboard/presentation/widgets/dashboard_school_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('campus map lays out inside a vertically scrolling page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CampusMapHazardApp(snapshot: _emptySnapshot()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

DashboardSnapshot _emptySnapshot() => const DashboardSnapshot(
  zones: [],
  devices: [],
  sensors: [],
  sensorReadings: [],
  occupancyReadings: [],
  zoneRisks: [],
  incidents: [],
  alerts: [],
  routes: [],
  userProfile: null,
);
