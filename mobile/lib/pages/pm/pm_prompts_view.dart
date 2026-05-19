import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/prompts_api.dart';
import '../../core/api/api_client.dart';
import '../../core/models/prompt.dart';
import '../../core/theme/app_colors.dart';

class PMPromptsView extends StatefulWidget {
  const PMPromptsView({super.key});

  @override
  State<PMPromptsView> createState() => _PMPromptsViewState();
}

class _PMPromptsViewState extends State<PMPromptsView> {
  List<Prompt> _prompts = [];
  bool _loadingPrompts = true;

  @override
  void initState() {
    super.initState();
    _fetchPrompts();
  }

  Future<void> _fetchPrompts() async {
    setState(() => _loadingPrompts = true);
    try {
      final list = await PromptsApi.list();
      if (mounted) {
        setState(() {
          _prompts = list;
          _loadingPrompts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPrompts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load prompts: $e')),
        );
      }
    }
  }

  Future<void> _toggleStatus(Prompt p) async {
    try {
      await PromptsApi.updateStatus(
        p.id,
        p.isActive ? 'closed' : 'active',
      );
      _fetchPrompts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  void _showNewPromptModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewPromptBottomSheet(onCreated: _fetchPrompts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _prompts.where((p) => p.isActive).toList();
    final closed = _prompts.where((p) => !p.isActive).toList();

    Widget content = RefreshIndicator(
      onRefresh: _fetchPrompts,
      child: _loadingPrompts
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Prompts (${active.length})',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _showNewPromptModal,
                          child: const Text('+ New Prompt'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (active.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Text(
                        'No active prompts. Create one to ask your analysts.',
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => _PromptCard(
                          prompt: active[index],
                          onToggleStatus: () => _toggleStatus(active[index]),
                          onViewResponses: () =>
                              context.push('/pm/prompts/${active[index].id}'),
                        ),
                        childCount: active.length,
                      ),
                    ),
                  ),
                if (closed.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Closed Prompts',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => _PromptCard(
                          prompt: closed[index],
                          onToggleStatus: () => _toggleStatus(closed[index]),
                          onViewResponses: () =>
                              context.push('/pm/prompts/${closed[index].id}'),
                        ),
                        childCount: closed.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Prompts', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: content,
    );
  }
}

class _PromptCard extends StatelessWidget {
  final Prompt prompt;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewResponses;

  const _PromptCard({
    required this.prompt,
    required this.onToggleStatus,
    required this.onViewResponses,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.65)
        : AppColors.surfaceLight.withValues(alpha: 0.80);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final dt = DateTime.tryParse(prompt.createdAt)?.toLocal();
    final dateStr = dt != null ? DateFormat('MMM d, yyyy').format(dt) : '';
    final deadlineDt = prompt.deadline != null ? DateTime.tryParse(prompt.deadline!)?.toLocal() : null;
    final deadlineStr = deadlineDt != null ? DateFormat('MMM d, yyyy').format(deadlineDt) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  prompt.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
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
          Text(
            deadlineStr != null ? 'Deadline: $deadlineStr' : 'Created $dateStr',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? AppColors.textDark3 : AppColors.textLight3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onViewResponses,
                  child: const Text('View Responses'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onToggleStatus,
                child: Text(prompt.isActive ? 'Close' : 'Reopen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewPromptBottomSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _NewPromptBottomSheet({required this.onCreated});

  @override
  State<_NewPromptBottomSheet> createState() => _NewPromptBottomSheetState();
}

class _NewPromptBottomSheetState extends State<_NewPromptBottomSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _deadline;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await PromptsApi.create(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        deadline: _deadline?.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = extractError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Prompt',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(
                _error!,
                style: GoogleFonts.inter(color: AppColors.error, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Topic / Question',
                hintText: "What's your view on energy sector rotation?",
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Context (optional)',
                hintText: 'Additional context for analysts…',
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _deadline == null
                    ? 'Set Deadline (optional)'
                    : 'Deadline: ${DateFormat('MMM d, yyyy h:mm a').format(_deadline!)}',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _deadline = DateTime(
                        date.year, date.month, date.day,
                        time.hour, time.minute,
                      );
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Prompt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
