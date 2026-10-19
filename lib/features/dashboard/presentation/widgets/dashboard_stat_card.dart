import 'dart:async';

import 'package:flutter/material.dart';

class DashboardEntrance extends StatefulWidget {
  const DashboardEntrance({
    super.key,
    required this.child,
    this.index = 0,
  });

  final Widget child;
  final int index;

  @override
  State<DashboardEntrance> createState() => _DashboardEntranceState();
}

class _DashboardEntranceState extends State<DashboardEntrance> {
  Timer? _entranceTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _scheduleEntrance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entranceTimer?.cancel();
      _visible = true;
    }
  }

  @override
  void didUpdateWidget(covariant DashboardEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _entranceTimer?.cancel();
      _visible = false;
      _scheduleEntrance();
    }
  }

  void _scheduleEntrance() {
    _entranceTimer = Timer(
      Duration(milliseconds: widget.index.clamp(0, 6) * 65),
      () {
        if (mounted) setState(() => _visible = true);
      },
    );
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: !_visible && !reduceMotion,
      child: ExcludeSemantics(
        excluding: !_visible && !reduceMotion,
        child: AnimatedOpacity(
          opacity: _visible || reduceMotion ? 1 : 0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: _visible || reduceMotion
                ? Offset.zero
                : const Offset(0, 0.035),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;

          return Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 18),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _StatIcon(icon: icon, color: color, size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AnimatedValue(
                              value: value,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.65),
                          fontSize: 10,
                          letterSpacing: 0.65,
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.55),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _StatIcon(icon: icon, color: color, size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface.withValues(alpha: 0.65),
                                fontSize: 10,
                                letterSpacing: 0.65,
                              ),
                            ),
                            const SizedBox(height: 5),
                            _AnimatedValue(
                              value: value,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface.withValues(alpha: 0.55),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue({
    required this.value,
    required this.style,
    this.textAlign,
  });

  final String value;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        value,
        key: ValueKey(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

class _StatIcon extends StatelessWidget {
  const _StatIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.72, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 460),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Icon(icon, color: color),
      ),
    );
  }
}
