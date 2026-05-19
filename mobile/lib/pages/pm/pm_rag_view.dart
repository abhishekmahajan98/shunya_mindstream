import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/api/rag_api.dart';
import '../../core/api/api_client.dart';
import '../../core/models/rag_result.dart';
import '../../core/theme/app_colors.dart';

class PMRagView extends StatefulWidget {
  const PMRagView({super.key});

  @override
  State<PMRagView> createState() => _PMRagViewState();
}

class _PMRagViewState extends State<PMRagView> {
  final _queryController = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _loading = false;
  RagResult? _result;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_queryController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final res = await RagApi.query(
        query: _queryController.text.trim(),
        dateFrom: _dateFrom?.toUtc().toIso8601String(),
        dateTo: _dateTo?.toUtc().toIso8601String(),
      );
      if (mounted) {
        setState(() {
          _result = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractError(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.65)
        : AppColors.surfaceLight.withValues(alpha: 0.80);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        decoration: const InputDecoration(
                          hintText: 'Search anything about analyst views…',
                        ),
                        onSubmitted: (_) => _run(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _run,
                      child: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(_dateFrom == null ? 'From' : DateFormat('MMM d, yyyy').format(_dateFrom!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _dateFrom = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(_dateTo == null ? 'To' : DateFormat('MMM d, yyyy').format(_dateTo!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _dateTo = d);
                        },
                      ),
                    ),
                    if (_dateFrom != null || _dateTo != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _dateFrom = null;
                          _dateTo = null;
                        }),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: GoogleFonts.inter(color: AppColors.error)),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
          if (_result != null)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: MarkdownBody(
                  data: _result!.answer,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                ),
              ),
            ),
          if (_result != null && _result!.sources.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              sliver: SliverToBoxAdapter(
                child: Text('Sources', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, idx) {
                  final src = _result!.sources[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note from ${src.analystName}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.teal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          src.transcript,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: _result!.sources.length,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
