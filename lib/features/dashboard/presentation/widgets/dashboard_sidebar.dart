import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.isOnline,
    required this.isChecking,
    required this.onDestinationSelected,
  });

  static const _items = [
    (Icons.dashboard_rounded, 'Overview'),
    (Icons.map_rounded, 'Live map'),
    (Icons.sensors_rounded, 'Sensors'),
    (Icons.groups_rounded, 'Occupancy'),
    (Icons.warning_amber_rounded, 'Alerts'),
    (Icons.settings_rounded, 'Settings'),
  ];

  final int selectedIndex;
  final bool isOnline;
  final bool isChecking;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 28),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AEGIS GRID',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < _items.length; index++)
            _NavigationEntry(
              icon: _items[index].$1,
              label: _items[index].$2,
              selected: index == selectedIndex,
              onTap: () => onDestinationSelected(index),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _SystemStatus(isOnline: isOnline, isChecking: isChecking),
          ),
        ],
      ),
    );
  }
}

class _NavigationEntry extends StatelessWidget {
  const _NavigationEntry({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.primary
        : colors.onSurface.withValues(alpha: 0.65);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 13),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemStatus extends StatelessWidget {
  const _SystemStatus({required this.isOnline, required this.isChecking});

  final bool isOnline;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = isChecking
        ? const Color(0xFFF6C453)
        : isOnline
        ? const Color(0xFF55C987)
        : const Color(0xFFE6A23C);
    final statusLabel = isChecking
        ? 'Checking services'
        : isOnline
        ? 'System online'
        : 'Setup required';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
