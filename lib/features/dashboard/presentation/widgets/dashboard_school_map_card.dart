import 'package:fire_evacuation_app/features/dashboard/data/dashboard_snapshot.dart';
import 'package:flutter/material.dart';

class CampusMapHazardApp extends StatelessWidget {
  const CampusMapHazardApp({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: MaterialApp(
        title: 'Campus Hazard Map',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
          useMaterial3: true,
        ),
        home: HazardMapScreen(snapshot: snapshot),
      ),
    );
  }
}

class CampusZone {
  final String id;
  final String label;
  final String imageAsset;
  final String description;
  final String? databaseZoneName;

  const CampusZone({
    required this.id,
    required this.label,
    required this.imageAsset,
    required this.description,
    this.databaseZoneName,
  });
}

class HazardMapScreen extends StatefulWidget {
  const HazardMapScreen({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  State<HazardMapScreen> createState() => _HazardMapScreenState();
}

class _HazardMapScreenState extends State<HazardMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Exact canvas dimensions ensuring 0% coordinate overlap
  static const double _canvasWidth = 720;
  static const double _canvasHeight = 960;

  // Uniform theme palette for standard state
  static const Color _defaultBg = Color(0xFFE2E8F0);
  static const Color _defaultBorder = Color(0xFF94A3B8);
  static const Color _defaultText = Color(0xFF1E293B);

  final Map<String, CampusZone> _zones = const {
    'reading_room': CampusZone(
      id: 'reading_room',
      label: 'Reading Room',
      imageAsset: 'assets/reading_room.jpg',
      description: 'Quiet library study halls and document archives.',
    ),
    'block_1': CampusZone(
      id: 'block_1',
      label: 'Block-I',
      imageAsset: 'assets/block_1.jpg',
      description: 'North academic wing, labs, and lecture classrooms.',
    ),
    'block_2': CampusZone(
      id: 'block_2',
      label: 'Block-II',
      imageAsset: 'assets/block_2.jpg',
      description: 'Upper tutorial rooms and faculty chambers.',
    ),
    'block_a': CampusZone(
      id: 'block_a',
      label: 'Block-A',
      imageAsset: 'assets/block_a.jpg',
      description: 'Central administrative department and registrar desks.',
      databaseZoneName: 'BLOCK A',
    ),
    'conference_hall': CampusZone(
      id: 'conference_hall',
      label: 'Conference Hall',
      imageAsset: 'assets/conference_hall.jpg',
      description: 'Executive seminar and syndicate conference chambers.',
    ),
    'central_lawn': CampusZone(
      id: 'central_lawn',
      label: 'Central Lawn',
      imageAsset: 'assets/central_lawn.jpg',
      description: 'Main campus open green commons and gathering ground.',
    ),
    'kapalala': CampusZone(
      id: 'kapalala',
      label: 'Kapalala',
      imageAsset: 'assets/kapalala.jpg',
      description: 'Open air amphitheatre, pavilion, and stage canopy.',
    ),
    'ef_park': CampusZone(
      id: 'ef_park',
      label: 'E/F Park',
      imageAsset: 'assets/ef_park.jpg',
      description: 'Botanical promenade and perimeter walkway.',
    ),
    'science_park': CampusZone(
      id: 'science_park',
      label: 'Science Park',
      imageAsset: 'assets/science_park.jpg',
      description: 'Outdoor scientific apparatus and interactive models.',
    ),
    'reception': CampusZone(
      id: 'reception',
      label: 'Reception',
      imageAsset: 'assets/reception.jpg',
      description: 'Campus reception desk, enquiries, and visitor check-in.',
    ),
    'gate_1': CampusZone(
      id: 'gate_1',
      label: 'Gate No. 1',
      imageAsset: 'assets/gate_1.jpg',
      description: 'Primary vehicular entrance and security booth.',
    ),
    'x_corridor': CampusZone(
      id: 'x_corridor',
      label: 'X-I | X-G | X-F | X-E Road',
      imageAsset: 'assets/service_road.jpg',
      description: 'Transitional pedestrian corridor and cross-lane junctions.',
    ),
    'gate_2_top': CampusZone(
      id: 'gate_2_top',
      label: 'Gate No. 2',
      imageAsset: 'assets/gate_2.jpg',
      description: 'Eastern entrance checkpoint and transit portal.',
    ),
    'canteen_ramp': CampusZone(
      id: 'canteen_ramp',
      label: 'Canteen & Ramp',
      imageAsset: 'assets/canteen.jpg',
      description: 'Campus cafeteria, food courts, and wheelchair ramps.',
      databaseZoneName: 'Cafeteria',
    ),
    'fields': CampusZone(
      id: 'fields',
      label: 'D-Cent & Q-Eai\nField Strip',
      imageAsset: 'assets/fields.jpg',
      description: 'Western sports field strip and shaded tree boundary.',
    ),
    'block_p': CampusZone(
      id: 'block_p',
      label: 'Block P',
      imageAsset: 'assets/block_p.jpg',
      description: 'South major academic complex, design studios, and labs.',
    ),
    'dispensary': CampusZone(
      id: 'dispensary',
      label: 'Dispensary & Lift',
      imageAsset: 'assets/dispensary.jpg',
      description:
          'First aid clinic, medical emergency bay, and tower elevator.',
    ),
    'auditorium': CampusZone(
      id: 'auditorium',
      label: 'Auditorium\n(Basement)',
      imageAsset: 'assets/auditorium.jpg',
      description:
          'Underground events auditorium, theater stage, and acoustics arena.',
    ),
    'south_service_lane': CampusZone(
      id: 'south_service_lane',
      label: 'South Service Lane',
      imageAsset: 'assets/service_lane.jpg',
      description: 'Emergency vehicle bypass and logistics accessway.',
    ),
    'grapche': CampusZone(
      id: 'grapche',
      label: 'Grapche',
      imageAsset: 'assets/grapche.jpg',
      description: 'Southern terminal gate and outer bypass loop.',
    ),
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static String _normalizeZoneName(Object? value) {
    return value.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isDangerous(CampusZone mapZone) {
    final databaseZoneName = mapZone.databaseZoneName;
    if (databaseZoneName == null) return false;
    final normalizedName = _normalizeZoneName(databaseZoneName);
    final matchingZone = widget.snapshot.zones.where(
      (zone) => _normalizeZoneName(zone['name']) == normalizedName,
    );
    return matchingZone.isNotEmpty &&
        widget.snapshot.activeDangerZoneIds.contains(
          matchingZone.first['id']?.toString(),
        );
  }

  List<String> get _unmappedDangerNames {
    final mappedNames = _zones.values
        .map((zone) => zone.databaseZoneName)
        .whereType<String>()
        .map(_normalizeZoneName)
        .toSet();
    final zoneNames = {
      for (final zone in widget.snapshot.zones)
        zone['id']?.toString(): zone['name']?.toString(),
    };
    return widget.snapshot.activeDangerZoneIds
        .where((zoneId) {
          final name = zoneNames[zoneId];
          return name == null ||
              !mappedNames.contains(_normalizeZoneName(name));
        })
        .map((zoneId) => zoneNames[zoneId] ?? 'Zone $zoneId')
        .toList(growable: false);
  }

  void _showZoneModal(CampusZone zone) {
    showDialog(
      context: context,
      builder: (context) {
        final isDanger = _isDangerous(zone);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      Center(
                        child: Image.asset(
                          zone.imageAsset,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 170,
                                color: isDanger
                                    ? Colors.red.shade50
                                    : Colors.grey.shade200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isDanger
                                          ? Icons.warning_rounded
                                          : Icons.apartment,
                                      size: 48,
                                      color: isDanger
                                          ? Colors.red.shade700
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      zone.label.replaceAll('\n', ' '),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDanger
                                            ? Colors.red.shade900
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      if (isDanger)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.report,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'HAZARD DETECTED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.label.replaceAll('\n', ' - '),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          zone.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black87, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isDanger
                              ? 'A sensor alert is active in this zone. '
                                    'The map clears it when sensor readings '
                                    'return to a safe level.'
                              : 'No active sensor alert is reported for '
                                    'this zone.',
                          style: TextStyle(
                            color: isDanger
                                ? Colors.red.shade800
                                : Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapBox({
    required String zoneId,
    required double width,
    required double height,
    double fontSize = 11,
  }) {
    final zone = _zones[zoneId]!;
    final isDanger = _isDangerous(zone);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return InkWell(
          onTap: () => _showZoneModal(zone),
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: width,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDanger
                  ? Color.lerp(
                      Colors.red.shade600,
                      Colors.red.shade900,
                      _pulseAnimation.value,
                    )
                  : _defaultBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDanger ? Colors.red.shade200 : _defaultBorder,
                width: isDanger ? 2.0 : 1.2,
              ),
              boxShadow: isDanger
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(
                          alpha: _pulseAnimation.value * 0.6,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDanger) ...[
                      const Icon(Icons.warning, color: Colors.white, size: 14),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      zone.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: isDanger ? Colors.white : _defaultText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),

      body: Column(
        children: [
          if (_unmappedDangerNames.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: Colors.red.shade50,
              child: Text(
                'Active sensor alert not placed on this map: '
                '${_unmappedDangerNames.join(', ')}. '
                'Add a verified map location for this zone.',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: InteractiveViewer(
              minScale: 0.6,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(80),
              child: Center(
                child: Container(
                  width: _canvasWidth,
                  height: _canvasHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // ================= 1. NORTH HEADER ROAD =================
                      // Y: 15 -> 41
                      Positioned(
                        left: 50,
                        top: 15,
                        child: Container(
                          width: 430,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Service Lane (Block H)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 495,
                        top: 15,
                        child: _buildMapBox(
                          zoneId: 'reception',
                          width: 105,
                          height: 38,
                        ),
                      ),
                      Positioned(
                        left: 610,
                        top: 15,
                        child: _buildMapBox(
                          zoneId: 'gate_1',
                          width: 75,
                          height: 38,
                        ),
                      ),

                      // ================= 2. ACADEMIC CLUSTER =================
                      // Y: 52 -> 87
                      Positioned(
                        left: 50,
                        top: 52,
                        child: _buildMapBox(
                          zoneId: 'block_1',
                          width: 135,
                          height: 35,
                        ),
                      ),
                      Positioned(
                        left: 195,
                        top: 52,
                        child: _buildMapBox(
                          zoneId: 'block_2',
                          width: 140,
                          height: 35,
                        ),
                      ),
                      // Y: 95 -> 143
                      Positioned(
                        left: 50,
                        top: 95,
                        child: _buildMapBox(
                          zoneId: 'reading_room',
                          width: 135,
                          height: 48,
                        ),
                      ),
                      Positioned(
                        left: 195,
                        top: 95,
                        child: _buildMapBox(
                          zoneId: 'block_a',
                          width: 140,
                          height: 48,
                        ),
                      ),

                      // ================= 3. EAST PARKS =================
                      // Y: 65 -> 245
                      Positioned(
                        left: 390,
                        top: 65,
                        child: _buildMapBox(
                          zoneId: 'ef_park',
                          width: 45,
                          height: 180,
                          fontSize: 10,
                        ),
                      ),
                      Positioned(
                        left: 445,
                        top: 65,
                        child: _buildMapBox(
                          zoneId: 'science_park',
                          width: 240,
                          height: 180,
                          fontSize: 13,
                        ),
                      ),

                      // ================= 4. CENTRAL COMMONS & STAGE =================
                      // Y: 153 -> 293
                      Positioned(
                        left: 50,
                        top: 153,
                        child: _buildMapBox(
                          zoneId: 'conference_hall',
                          width: 85,
                          height: 140,
                        ),
                      ),
                      Positioned(
                        left: 145,
                        top: 153,
                        child: _buildMapBox(
                          zoneId: 'central_lawn',
                          width: 235,
                          height: 90,
                          fontSize: 13,
                        ),
                      ),
                      Positioned(
                        left: 145,
                        top: 251,
                        child: _buildMapBox(
                          zoneId: 'kapalala',
                          width: 235,
                          height: 42,
                        ),
                      ),

                      // ================= 5. MID TRANSIT & CANTEEN =================
                      // Y: 305 -> 380
                      Positioned(
                        left: 50,
                        top: 305,
                        child: Container(
                          width: 330,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Service Lane (Block H) Road',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 50,
                        top: 336,
                        child: _buildMapBox(
                          zoneId: 'x_corridor',
                          width: 330,
                          height: 44,
                        ),
                      ),
                      Positioned(
                        left: 400,
                        top: 270,
                        child: _buildMapBox(
                          zoneId: 'gate_2_top',
                          width: 100,
                          height: 35,
                        ),
                      ),
                      Positioned(
                        left: 400,
                        top: 315,
                        child: _buildMapBox(
                          zoneId: 'canteen_ramp',
                          width: 170,
                          height: 65,
                        ),
                      ),

                      // ================= 6. SOUTH-WEST DIAGONAL CORRIDOR =================
                      // Y: 405 -> 605 (Non-overlapping with Y <= 380 above)
                      Positioned(
                        left: 175,
                        top: 405,
                        child: _buildMapBox(
                          zoneId: 'fields',
                          width: 80,
                          height: 200,
                        ),
                      ),
                      Positioned(
                        left: 265,
                        top: 405,
                        child: _buildMapBox(
                          zoneId: 'block_p',
                          width: 145,
                          height: 180,
                          fontSize: 13,
                        ),
                      ),
                      Positioned(
                        left: 420,
                        top: 405,
                        child: _buildMapBox(
                          zoneId: 'dispensary',
                          width: 90,
                          height: 150,
                        ),
                      ),

                      // Y: 615 -> 745 (Cleanly below Block P)
                      Positioned(
                        left: 215,
                        top: 615,
                        child: _buildMapBox(
                          zoneId: 'auditorium',
                          width: 155,
                          height: 130,
                          fontSize: 12,
                        ),
                      ),

                      // Y: 765 -> 845 (Cleanly below Auditorium)
                      Positioned(
                        left: 135,
                        top: 765,
                        child: _buildMapBox(
                          zoneId: 'south_service_lane',
                          width: 165,
                          height: 75,
                        ),
                      ),

                      // Y: 865 -> 935 (Terminal south-west point)
                      Positioned(
                        left: 50,
                        top: 865,
                        child: _buildMapBox(
                          zoneId: 'grapche',
                          width: 130,
                          height: 65,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
