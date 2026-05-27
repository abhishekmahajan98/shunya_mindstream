import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
      // Router redirect will handle navigation
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final hiveGold = AppColors.teal;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Ambient blobs
          _Blob(top: -120, left: -80, color: hiveGold.withValues(alpha: 0.07)),
          _Blob(bottom: -100, right: -60, color: AppColors.violet.withValues(alpha: 0.05)),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Heading
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ambient gold glow backing
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.teal.withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                // Glassmorphic border hexagon
                                SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: CustomPaint(
                                    painter: _LoginHexagonPainter(isDark: isDark),
                                  ),
                                ),
                                // Glowing golden hive (honeycomb) icon
                                Icon(
                                  Icons.hive,
                                  color: AppColors.teal,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Mindstream',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              )),
                          const SizedBox(height: 6),
                          Text('Voice-first investment research',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Card
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Sign in',
                              style: GoogleFonts.inter(
                                fontSize: 18, fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              )),
                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            _ErrorBanner(_error!),
                            const SizedBox(height: 16),
                          ],

                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sign in'),
                          ),
                          const SizedBox(height: 16),

                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/signup'),
                              child: Text(
                                "Don't have an account? Sign up",
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.65)
            : AppColors.surfaceLight.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: child,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: AppColors.teal.withValues(alpha: 0.85), width: 3),
          top: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
          right: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
          bottom: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double? top, bottom, left, right;
  final Color color;
  const _Blob({this.top, this.bottom, this.left, this.right, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

// ── Private Custom Hexagon Painter for Login Logo ─────────────
class _LoginHexagonPainter extends CustomPainter {
  final bool isDark;
  final double cornerRadius;

  _LoginHexagonPainter({
    required this.isDark,
    this.cornerRadius = 10.0,
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

    // 1. Draw Gold Shadow
    final shadowColor = AppColors.teal.withValues(alpha: 0.35);
    canvas.drawPath(
      path,
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0),
    );

    // 2. Draw Translucent Fill
    final fillColor = isDark 
        ? AppColors.surfaceDark.withValues(alpha: 0.35) 
        : AppColors.surfaceLight.withValues(alpha: 0.45);
    canvas.drawPath(
      path,
      Paint()..color = fillColor,
    );

    // 3. Draw Gold Border
    final borderColor = AppColors.teal.withValues(alpha: 0.8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = borderColor
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginHexagonPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
