import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/api/prompts_api.dart';
import '../../core/models/prompt_responses_result.dart';
import '../../core/theme/app_colors.dart';

class PromptResponsesPage extends StatefulWidget {
  final String promptId;

  const PromptResponsesPage({super.key, required this.promptId});

  @override
  State<PromptResponsesPage> createState() => _PromptResponsesPageState();
}

class _PromptResponsesPageState extends State<PromptResponsesPage> {
  PromptResponsesResult? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await PromptsApi.getResponses(widget.promptId);
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.65)
        : AppColors.surfaceLight.withValues(alpha: 0.80);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.go('/pm'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: GoogleFonts.inter(color: AppColors.error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _fetch, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_data == null) return const Scaffold();

    final prompt = _data!.prompt;
    final recordings = _data!.recordings;
    final summary = _data!.summary;

    final deadlineDt = prompt.deadline != null ? DateTime.tryParse(prompt.deadline!)?.toLocal() : null;
    final deadlineStr = deadlineDt != null ? DateFormat('MMM d, yyyy h:mm a').format(deadlineDt) : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/pm'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'Responses',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: prompt.isActive
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.textDark3.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              prompt.isActive ? 'Active' : 'Closed',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: prompt.isActive ? AppColors.success : (isDark ? AppColors.textDark3 : AppColors.textLight3),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: CustomScrollView(
          slivers: [
            // Prompt Detail Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (prompt.description != null && prompt.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          prompt.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 14,
                            color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${recordings.length} response${recordings.length == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                            ),
                          ),
                          if (deadlineStr != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 14,
                              color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Deadline: $deadlineStr',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Gemini synthesis card
            if (summary != null && summary.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '✦ Gemini Synthesis',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.teal,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _fetch,
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('Refresh'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        MarkdownBody(
                          data: summary,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: GoogleFonts.inter(height: 1.6, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Analyst Responses Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Analyst Responses',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Responses listing
            if (recordings.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No analyst responses yet.',
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final r = recordings[index];
                      final name = r.analystName ?? 'Unknown';
                      final avatarChar = name.isNotEmpty ? name[0].toUpperCase() : '?';

                      final rDt = DateTime.tryParse(r.createdAt)?.toLocal();
                      final rDateStr = rDt != null ? DateFormat('MMM d, h:mm a').format(rDt) : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: activeColor.withValues(alpha: 0.15),
                                  child: Text(
                                    avatarChar,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: activeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              r.transcript,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.5,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              rDateStr,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: recordings.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
