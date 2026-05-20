import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'analyst';
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).signup(
        _email.text.trim(), _password.text, _name.text.trim(), _role,
      );
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
    const teal = Color(0xFFEDAC33); // HIVE Gold Color
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          _Blob(top: -80, right: -60, color: teal.withValues(alpha: 0.06)),
          _Blob(bottom: -120, left: -80, color: AppColors.violet.withValues(alpha: 0.05)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ambient gold glow backing
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEDAC33).withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                // Glassmorphic border hexagon
                                SizedBox(
                                  width: 62,
                                  height: 62,
                                  child: CustomPaint(
                                    painter: _SignupHexagonPainter(isDark: isDark),
                                  ),
                                ),
                                // Glowing golden hive (honeycomb) icon
                                const Icon(
                                  Icons.hive,
                                  color: Color(0xFFEDAC33),
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Create Account',
                              style: GoogleFonts.inter(
                                  fontSize: 24, fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4, color: textColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark.withValues(alpha: 0.65)
                            : AppColors.surfaceLight.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Sign up',
                              style: GoogleFonts.inter(
                                  fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            _ErrorBanner(_error!),
                            const SizedBox(height: 16),
                          ],

                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline, size: 18),
                            ),
                          ),
                          const SizedBox(height: 14),
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
                                  size: 18),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Role selector
                          Text('Role',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: isDark ? AppColors.textDark2 : AppColors.textLight2)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _RoleChip(
                                label: 'Analyst',
                                selected: _role == 'analyst',
                                onTap: () => setState(() => _role = 'analyst'),
                              ),
                              const SizedBox(width: 10),
                              _RoleChip(
                                label: 'PM',
                                selected: _role == 'pm',
                                onTap: () => setState(() => _role = 'pm'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: _loading ? null : _signup,
                            child: _loading
                                ? const SizedBox(
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Create Account'),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/login'),
                              child: Text('Already have an account? Sign in',
                                  style: GoogleFonts.inter(fontSize: 13)),
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

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teal = isDark ? AppColors.teal : AppColors.tealDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? teal.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? teal : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? teal : (isDark ? AppColors.textDark2 : AppColors.textLight2),
          ),
        ),
      ),
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
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
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
        width: 280, height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

// ── Private Custom Hexagon Painter for Signup Logo ────────────
class _SignupHexagonPainter extends CustomPainter {
  final bool isDark;
  final double cornerRadius;

  _SignupHexagonPainter({
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
    final shadowColor = const Color(0xFFEDAC33).withValues(alpha: 0.35);
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
    final borderColor = const Color(0xFFEDAC33).withValues(alpha: 0.8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = borderColor
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SignupHexagonPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
