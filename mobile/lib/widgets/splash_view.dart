import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import 'mindstream_aura.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _spacingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward(); // Run once, smoothly fading in

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.8, curve: Curves.easeOut)),
    );
    
    _spacingAnimation = Tween<double>(begin: 2.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Centered Honeycomb grid cluster stack
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Slowly breathing gold honeycomb grid
                        const MindstreamAura(
                          isActive: false,
                          isLoading: true,
                        ),
                        // Glassmorphic central gold hexagon
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: CustomPaint(
                            painter: _SplashHexagonPainter(isDark: isDark),
                          ),
                        ),
                        // Glowing golden hive (honeycomb) icon
                        const Icon(
                          Icons.hive,
                          color: Color(0xFFEDAC33),
                          size: 42,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'SHUNYA',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEDAC33),
                      letterSpacing: _spacingAnimation.value,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mindstream',
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w200,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Private Custom Hexagon Painter for Splash Central Logo ─────
class _SplashHexagonPainter extends CustomPainter {
  final bool isDark;
  final double cornerRadius;

  _SplashHexagonPainter({
    required this.isDark,
    this.cornerRadius = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2;

    final angles = List.generate(6, (i) => -math.pi / 2 + i * math.pi / 3);
    final vertices = angles.map((a) => Offset(cx + r * math.cos(a), cy + r * math.sin(a))).toList();

    final path = Path();
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

    // 1. Draw Gold Shadow/Glow
    final shadowColor = const Color(0xFFEDAC33).withOpacity(0.35);
    canvas.drawPath(
      path,
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0),
    );

    // 2. Draw Translucent Fill
    final fillColor = isDark 
        ? AppColors.surfaceDark.withOpacity(0.35) 
        : AppColors.surfaceLight.withOpacity(0.45);
    canvas.drawPath(
      path,
      Paint()..color = fillColor,
    );

    // 3. Draw Gold Border
    final borderColor = const Color(0xFFEDAC33).withOpacity(0.8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = borderColor
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashHexagonPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
