import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/prompts_api.dart';
import '../../core/models/prompt.dart';
import '../../core/theme/app_colors.dart';

class PromptsView extends StatefulWidget {
  final Prompt? selectedPrompt;
  final ValueChanged<Prompt?> onPromptSelected;
  final VoidCallback onBackToStream;

  const PromptsView({
    super.key,
    required this.selectedPrompt,
    required this.onPromptSelected,
    required this.onBackToStream,
  });

  @override
  State<PromptsView> createState() => _PromptsViewState();
}

class _PromptsViewState extends State<PromptsView> {
  List<Prompt> _prompts = [];
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
      final all = await PromptsApi.list();
      final active = all.where((p) => p.isActive).toList();
      if (mounted) {
        setState(() {
          _prompts = active;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PM Prompts',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_prompts.length} active research prompt${_prompts.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _prompts.isEmpty
                ? Center(
                    child: Text(
                      'No active prompts right now.',
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _prompts.length,
                    itemBuilder: (context, index) {
                      final p = _prompts[index];
                      final isSelected = widget.selectedPrompt?.id == p.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            widget.onPromptSelected(isSelected ? null : p);
                            widget.onBackToStream();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? activeColor : border,
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.textDark : AppColors.textLight,
                                        ),
                                      ),
                                      if (p.description != null && p.description!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          p.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            height: 1.5,
                                            color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.check_circle_outline, color: activeColor, size: 22),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
