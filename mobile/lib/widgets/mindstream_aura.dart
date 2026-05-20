import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated custom visualizer widget. Renders a perfect edge-sharing honeycomb wall
/// starting directly from the central record button and fading out near the screen boundaries.
class MindstreamAura extends StatefulWidget {
  final bool isActive;    // recording in progress
  final bool isLoading;   // initialising
  final double amplitude; // 0.0–1.0 from speech_to_text sound level

  const MindstreamAura({
    super.key,
    required this.isActive,
    required this.isLoading,
    this.amplitude = 0.0,
  });

  @override
  State<MindstreamAura> createState() => _MindstreamAuraState();
}

class _MindstreamAuraState extends State<MindstreamAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _smoothedAmplitude = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // continuous loop
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        // Linearly interpolate amplitude to smooth out microphone jitter
        _smoothedAmplitude += (widget.amplitude - _smoothedAmplitude) * 0.15;
        
        return CustomPaint(
          painter: _AuraPainter(
            t: _ctrl.value * math.pi * 2 * 60 * 0.015,
            amplitude: _smoothedAmplitude,
            isActive: widget.isActive,
            isLoading: widget.isLoading,
            isDark: isDark,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

// ── Custom Painter ────────────────────────────────────────────
class _AuraPainter extends CustomPainter {
  final double t;
  final double amplitude;
  final bool isActive;
  final bool isLoading;
  final bool isDark;

  const _AuraPainter({
    required this.t,
    required this.amplitude,
    required this.isActive,
    required this.isLoading,
    required this.isDark,
  });

  // Helper to generate a straight-edged rounded hexagon path
  Path getRoundedHexagonPath(double cx, double cy, double r, double rotationAngle, double cornerRadius) {
    final path = Path();
    final angles = List.generate(6, (i) => -math.pi / 2 + i * math.pi / 3 + rotationAngle);
    final vertices = angles.map((a) => Offset(cx + r * math.cos(a), cy + r * math.sin(a))).toList();

    for (int i = 0; i < 6; i++) {
      final pPrev = vertices[(i - 1 + 6) % 6];
      final pCurr = vertices[i];
      final pNext = vertices[(i + 1) % 6];

      final vPrev = pPrev - pCurr;
      final vNext = pNext - pCurr;

      final dPrev = vPrev.distance;
      final dNext = vNext.distance;

      final len = math.min(cornerRadius, math.min(dPrev, dNext) / 2);

      final pStart = pCurr + vPrev * (len / dPrev);
      final pEnd = pCurr + vNext * (len / dNext);

      if (i == 0) {
        path.moveTo(pStart.dx, pStart.dy);
      } else {
        path.lineTo(pStart.dx, pStart.dy);
      }
      path.quadraticBezierTo(pCurr.dx, pCurr.dy, pEnd.dx, pEnd.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Beehive Warm Honey/Gold color (#EDAC33)
    const hiveColor = Color(0xFFEDAC33);

    // Grid center-to-center offset sizing (matches record button radius 55)
    const gridR = 55.0;
    
    // Draw sizing: slightly smaller to create clear, aesthetic gaps between cells
    const drawR = gridR - 4.5; // 50.5 (results in 4px gap to center, 7.8px gap between cells)
    const drawCornerRadius = 12.85; // Proportional corner radius for drawR

    // Wave propagation timing
    final wavePhase = isActive ? t * 3.5 : t * 1.0;

    // Axial coordinate loop to tile the screen
    const range = 4;
    for (int q = -range; q <= range; q++) {
      for (int r = -range; r <= range; r++) {
        if ((q + r).abs() <= range) {
          // Skip center (q=0, r=0) because the main interactive record button is drawn there
          if (q == 0 && r == 0) continue;

          // Axial coordinates to pixel offsets translation
          final dx = gridR * (math.sqrt(3) * q + math.sqrt(3) / 2 * r);
          final dy = gridR * (1.5 * r);
          
          final cellCx = cx + dx;
          final cellCy = cy + dy;
          final dist = math.sqrt(dx * dx + dy * dy);

          // Get grid layer ring distance: Ring 1 (first layer), Ring 2 (second layer), etc.
          final int ring = (q.abs() + r.abs() + (q + r).abs()) ~/ 2;
          
          // Discrete layer-based fade factors matching user request:
          // Ring 1 (1st layer): bright (100% brightness)
          // Ring 2 (2nd layer): faded (70% brightness)
          // Ring 3 (3rd layer): more faded (42% brightness)
          // Ring 4 (4th layer): deeply faded (18% brightness)
          double layerFade = 0.0;
          if (ring == 1) {
            layerFade = 1.0;
          } else if (ring == 2) {
            layerFade = 0.70;
          } else if (ring == 3) {
            layerFade = 0.42;
          } else if (ring == 4) {
            layerFade = 0.18;
          }
          
          if (layerFade <= 0.0) continue;

          // Radial ripple propagation
          final phase = (dist / 110.0) - wavePhase;
          final ripple = 0.5 + 0.5 * math.sin(phase);

          // Modulate cell opacity based on active status, voice amplitude, and layer fade
          final double baseOpacity = isActive ? 0.58 : 0.24;
          final double rippleWeight = isActive ? (0.42 + amplitude * 0.58) : 0.16;
          final cellAlpha = (baseOpacity + ripple * rippleWeight) * layerFade;

          final cellPath = getRoundedHexagonPath(cellCx, cellCy, drawR, 0.0, drawCornerRadius);

          // 1. Draw soft translucent honey background fill
          final fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = hiveColor.withValues(alpha: (cellAlpha * 0.18).clamp(0.0, 1.0));
          canvas.drawPath(cellPath, fillPaint);

          // 2. Draw solid outer boundaries (with a gap and increased thickness)
          final strokePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 + (isActive ? amplitude * 1.2 : 0.0)
            ..color = hiveColor.withValues(alpha: cellAlpha.clamp(0.0, 1.0));
          canvas.drawPath(cellPath, strokePaint);

          // 3. Draw rotating inner droplet in center of each cell that scales with wave
          final innerScale = 0.45 + ripple * 0.15 + (isActive ? amplitude * 0.15 : 0.0);
          final innerR = drawR * innerScale;
          final innerPath = getRoundedHexagonPath(cellCx, cellCy, innerR, t * 0.15, drawCornerRadius * innerScale);
          
          final innerPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = hiveColor.withValues(alpha: (cellAlpha * 0.65).clamp(0.0, 1.0));
          canvas.drawPath(innerPath, innerPaint);
        }
      }
    }

    // 4. Background radial glow at the center to highlight record button backing
    final nucleusR = gridR * 1.5 * (1.0 + (isActive ? amplitude * 0.25 : 0.0));
    final nucleusAlpha = isActive ? 0.38 + amplitude * 0.32 : 0.18;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          hiveColor.withValues(alpha: nucleusAlpha.clamp(0.0, 1.0)),
          hiveColor.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: nucleusR * 2.2),
      );
    canvas.drawCircle(Offset(cx, cy), nucleusR * 2.2, glowPaint);
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.t != t ||
      old.amplitude != amplitude ||
      old.isActive != isActive ||
      old.isLoading != isLoading ||
      old.isDark != isDark;
}
