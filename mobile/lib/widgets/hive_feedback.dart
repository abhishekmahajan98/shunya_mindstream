import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// Consistent loading spinner using theme primary (hive gold).
class HiveLoadingIndicator extends StatelessWidget {
  final double? size;

  const HiveLoadingIndicator({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final s = size ?? 36;
    return Center(
      child: SizedBox(
        width: s,
        height: s,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Minimal error state: muted surface + hive accent rule + optional retry.
class HiveErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const HiveErrorPanel({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.teal : AppColors.tealDark;
    final surface = isDark
        ? AppColors.surfaceDark2.withValues(alpha: 0.6)
        : AppColors.surfaceLight2.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: accent, width: 3),
            top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            right: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: Text(
                    'Retry',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
