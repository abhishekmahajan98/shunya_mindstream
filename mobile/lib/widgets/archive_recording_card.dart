import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/models/recording.dart';
import '../core/theme/app_colors.dart';
import 'stat_chip.dart';

class ArchiveRecordingCard extends StatefulWidget {
  final Recording recording;
  const ArchiveRecordingCard({super.key, required this.recording});

  @override
  State<ArchiveRecordingCard> createState() => _ArchiveRecordingCardState();
}

class _ArchiveRecordingCardState extends State<ArchiveRecordingCard> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.recording;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surface = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.65)
        : AppColors.surfaceLight.withValues(alpha: 0.80);

    final dt = DateTime.tryParse(r.createdAt)?.toLocal();
    final timeStr = dt != null ? DateFormat('h:mm a').format(dt) : '';
    final dateStr = dt != null ? DateFormat('E, MMM d, yyyy').format(dt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timeStr,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textDark : AppColors.textLight)),
                        Text(dateStr,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? AppColors.textDark2 : AppColors.textLight2)),
                      ],
                    ),
                  ),
                  if (r.id.startsWith('pending_'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_queue_rounded, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'Waiting for internet',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Prompt banner
            if (r.promptTitle != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.teal, shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Response to: ${r.promptTitle}',
                        style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Transcript body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Text(
                r.transcript,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
