import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Animated concentric aura orb — mirrors the web MindstreamAura canvas.
/// Driven by a looping AnimationController (breathing) + amplitude (voice).
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
      duration: const Duration(seconds: 60), // long loop; painter uses raw value
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
        // Linearly interpolate amplitude for extremely smooth animations (removes microphone jitter)
        _smoothedAmplitude += (widget.amplitude - _smoothedAmplitude) * 0.15;
        
        return CustomPaint(
          painter: _AuraPainter(
            t: _ctrl.value * math.pi * 2 * 60 * 0.015, // matches web: frame*0.015
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

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Breathing scale (~5.5s period)
    final breatheCycle = isLoading ? t * 2.2 : t * 0.4;
    final breathe = 1.0 + 0.04 * math.sin(breatheCycle);
    final maxAllowedR = math.min(size.width, size.height) * 0.32;
    final baseR = maxAllowedR * breathe;

    // Draw 3 concentric organic rings
    for (int rIdx = 0; rIdx < 3; rIdx++) {
      final ringPhaseOffset = rIdx * (math.pi * 2 / 3);
      final ringScale = 0.65 + 0.35 * (rIdx / 2.0);
      final currentR = baseR * ringScale * (1.0 + amplitude * 0.15);

      final path = Path();
      const numPoints = 120;

      for (int i = 0; i <= numPoints; i++) {
        final angle = (i / numPoints) * math.pi * 2;
        final restingWave = 0.015 * math.sin(angle * 4 - t * 0.8 + ringPhaseOffset);
        final voiceWave = isActive
            ? (0.02 + amplitude * 0.08) *
                math.sin(angle * (8 + rIdx * 2) + t * 4.5)
            : 0.0;
        final totalRadius = currentR * (1.0 + restingWave + voiceWave);

        final shiftX =
            math.cos(t * 0.5 + ringPhaseOffset) * 6 * (1.0 - ringScale);
        final shiftY =
            math.sin(t * 0.4 + ringPhaseOffset) * 6 * (1.0 - ringScale);

        final x = cx + shiftX + math.cos(angle) * totalRadius;
        final y = cy + shiftY + math.sin(angle) * totalRadius;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      // Color based on state
      Color strokeColor;
      double alpha;
      double lineWidth;

      if (isActive) {
        // Meditative primary gold when recording
        strokeColor = isDark ? AppColors.teal : AppColors.tealDark;
        alpha = isDark
            ? (0.35 + (1 - ringScale) * 0.25 + amplitude * 0.35)
            : (0.28 + amplitude * 0.25);
        alpha *= (0.8 + 0.2 * math.sin(t + rIdx));
      } else if (isLoading) {
        strokeColor = isDark ? AppColors.teal : AppColors.tealDark;
        alpha = (isDark ? 0.30 : 0.22) + 0.05 * math.sin(t * 3);
      } else {
        // Warm sand at rest
        strokeColor = isDark ? AppColors.sand : AppColors.sandDark;
        alpha = isDark
            ? (0.18 + (1 - ringScale) * 0.18)
            : (0.18 + (1 - ringScale) * 0.16);
      }

      lineWidth = 1.5 + (1 - ringScale) * 1.5 + amplitude * 1.5;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..color = strokeColor.withValues(alpha: alpha.clamp(0, 1));

      canvas.drawPath(path, paint);
    }

    // Soft glowing feathered nucleus (no hard edges, pure premium glassmorphic feel)
    final nucleusR = baseR * 0.50 * (1.0 + amplitude * 0.15);
    Color nucleusColor;
    double nucleusAlpha;

    if (isActive) {
      nucleusColor = isDark ? AppColors.teal : AppColors.tealDark;
      nucleusAlpha = isDark
          ? (0.28 + amplitude * 0.20)
          : (0.18 + amplitude * 0.15);
    } else if (isLoading) {
      nucleusColor = isDark ? AppColors.teal : AppColors.tealDark;
      nucleusAlpha = isDark ? 0.20 : 0.08;
    } else {
      nucleusColor = isDark ? AppColors.sand : AppColors.sandDark;
      nucleusAlpha = isDark ? 0.15 : 0.08;
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          nucleusColor.withValues(alpha: nucleusAlpha.clamp(0, 1)),
          nucleusColor.withValues(alpha: 0),
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
