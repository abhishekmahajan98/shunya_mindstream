import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/api/prompts_api.dart';
import '../../core/api/rag_api.dart';
import '../../core/api/api_client.dart';
import '../../core/models/prompt.dart';
import '../../core/models/rag_result.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PMDashboardPage extends ConsumerStatefulWidget {
  const PMDashboardPage({super.key});

  @override
  ConsumerState<PMDashboardPage> createState() => _PMDashboardPageState();
}

class _PMDashboardPageState extends ConsumerState<PMDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Prompt> _prompts = [];
  bool _loadingPrompts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPrompts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrompts() async {
    setState(() => _loadingPrompts = true);
    try {
      final list = await PromptsApi.list();
      setState(() {
        _prompts = list;
        _loadingPrompts = false;
      });
    } catch (e) {
      setState(() => _loadingPrompts = false);
      if (mounted) {
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
    final profile = ref.watch(authProvider).profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _prompts.where((p) => p.isActive).toList();
    final closed = _prompts.where((p) => !p.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Shunya',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 4),
            Text(
              'Mindstream',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w300,
                fontSize: 18,
                color: isDark ? AppColors.textDark2 : AppColors.textLight2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
              ),
              child: Text(
                'PM',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? AppColors.teal : AppColors.tealDark,
          labelColor: isDark ? AppColors.teal : AppColors.tealDark,
          unselectedLabelColor: isDark ? AppColors.textDark3 : AppColors.textLight3,
          labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Prompts'),
            Tab(text: 'RAG Query'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // PROMPTS TAB
          RefreshIndicator(
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
                                    context.go('/pm/prompts/${active[index].id}'),
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
                                    context.go('/pm/prompts/${closed[index].id}'),
                              ),
                              childCount: closed.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // RAG TAB
          const _RagQueryView(),
        ],
      ),
    );
  }
}

// ── Prompts Card Widget ────────────────────────────────────────

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

// ── New Prompt Modal ──────────────────────────────────────────

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
      widget.onCreated();
      if (mounted) Navigator.pop(context);
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
    final textTheme = Theme.of(context).textTheme;

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

// ── RAG Query View ────────────────────────────────────────────

class _RagQueryView extends StatefulWidget {
  const _RagQueryView();

  @override
  State<_RagQueryView> createState() => _RagQueryViewState();
}

class _RagQueryViewState extends State<_RagQueryView> {
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
      setState(() {
        _result = res;
        _loading = false;
      });
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
                Text(
                  'Ask Your Analysts',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        decoration: const InputDecoration(
                          hintText: 'Ask anything about analyst views…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _run,
                      child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Ask'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateFilterTile(
                        label: _dateFrom == null
                            ? 'From Date'
                            : DateFormat('MMM d, yyyy').format(_dateFrom!),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _dateFrom = date);
                        },
                        onClear: _dateFrom != null
                            ? () => setState(() => _dateFrom = null)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateFilterTile(
                        label: _dateTo == null
                            ? 'To Date'
                            : DateFormat('MMM d, yyyy').format(_dateTo!),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _dateTo = date);
                        },
                        onClear: _dateTo != null
                            ? () => setState(() => _dateTo = null)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!, style: GoogleFonts.inter(color: AppColors.error)),
                  const SizedBox(height: 16),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Searching and synthesizing…'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_result != null) ...[
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: MarkdownBody(
                  data: _result!.answer,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: GoogleFonts.inter(height: 1.6, fontSize: 14),
                  ),
                ),
              ),
            ),
            if (_result!.sources.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Sources (${_result!.sources.length})',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final s = _result!.sources[index];
                    final sDt = DateTime.tryParse(s.createdAt)?.toLocal();
                    final sDateStr = sDt != null ? DateFormat('MMM d, yyyy').format(sDt) : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                s.analystName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '$sDateStr · ${s.type} · ${MathRound(s.similarity)}% match',
                                style: GoogleFonts.inter(
                                  color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.transcript,
                            style: GoogleFonts.inter(
                              height: 1.5,
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
            ],
          ],
        ],
      ),
    );
  }

  int MathRound(double num) {
    return (num * 100).round();
  }
}

class _DateFilterTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateFilterTile({
    required this.label,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight2;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: onTap,
        title: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13),
        ),
        trailing: onClear != null
            ? GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear, size: 16),
              )
            : const Icon(Icons.arrow_drop_down, size: 18),
      ),
    );
  }
}
