import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';

class DraftsView extends StatefulWidget {
  final Function(Map<String, dynamic> draft, int index) onDraftResumed;

  const DraftsView({super.key, required this.onDraftResumed});

  @override
  State<DraftsView> createState() => _DraftsViewState();
}

class _DraftsViewState extends State<DraftsView> {
  List<Map<String, dynamic>> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDrafts();
  }

  Future<void> _fetchDrafts() async {
    setState(() => _loading = true);
    final drafts = await SyncService.getDrafts();
    if (mounted) {
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    }
  }

  Future<void> _handleDelete(int index) async {
    await SyncService.deleteDraft(index);
    await _fetchDrafts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark2.withOpacity(0.5)
                      : AppColors.surfaceLight2.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 40,
                  color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No drafts yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Any drafts you save will appear here for you to resume recording or editing at any time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final d = _drafts[index];
        final border = isDark ? AppColors.borderDark : AppColors.borderLight;
        final surface = isDark
            ? AppColors.surfaceDark.withOpacity(0.65)
            : AppColors.surfaceLight.withOpacity(0.80);

        final localTsStr = d['local_timestamp'] as String? ?? '';
        final dt = DateTime.tryParse(localTsStr)?.toLocal();
        final timeStr = dt != null ? DateFormat('h:mm a').format(dt) : '';
        final dateStr = dt != null ? DateFormat('E, MMM d, yyyy').format(dt) : '';
        final transcript = d['transcript'] as String? ?? '';
        final promptTitle = d['prompt_title'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textDark : AppColors.textLight,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: AppColors.error,
                        ),
                        onPressed: () => _handleDelete(index),
                      ),
                    ],
                  ),
                ),

                // Prompt badge
                if (promptTitle != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Response to: $promptTitle',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Transcript Snippet
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Text(
                    transcript,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.5,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Bottom Action
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => widget.onDraftResumed(d, index),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          'Resume Draft',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
                          foregroundColor: isDark ? AppColors.teal : AppColors.tealDark,
                          elevation: 0,
                          side: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
