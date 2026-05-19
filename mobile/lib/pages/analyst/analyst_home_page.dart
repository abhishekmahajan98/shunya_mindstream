import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/prompt.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'stream_view.dart';
import 'archive_view.dart';
import 'prompts_view.dart';
import 'drafts_view.dart';
import '../../core/services/sync_service.dart';

class AnalystHomePage extends ConsumerStatefulWidget {
  const AnalystHomePage({super.key});

  @override
  ConsumerState<AnalystHomePage> createState() => _AnalystHomePageState();
}

class _AnalystHomePageState extends ConsumerState<AnalystHomePage> {
  // 'stream' | 'archive' | 'prompts' | 'drafts'
  String _viewMode = 'stream';
  Prompt? _selectedPrompt;
  Map<String, dynamic>? _resumingDraft;

  @override
  void initState() {
    super.initState();
    SyncService.syncPending();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

    Widget body;
    if (_viewMode == 'archive') {
      body = const ArchiveView();
    } else if (_viewMode == 'prompts') {
      body = PromptsView(
        selectedPrompt: _selectedPrompt,
        onPromptSelected: (p) => setState(() => _selectedPrompt = p),
        onBackToStream: () => setState(() => _viewMode = 'stream'),
      );
    } else if (_viewMode == 'drafts') {
      body = DraftsView(
        onDraftResumed: (draft, index) {
          setState(() {
            _resumingDraft = draft;
            _viewMode = 'stream';
          });
        },
      );
    } else {
      body = StreamView(
        selectedPrompt: _selectedPrompt,
        onClearPrompt: () => setState(() => _selectedPrompt = null),
        onPromptSelected: (p) => setState(() => _selectedPrompt = p),
        resumingDraft: _resumingDraft,
        onDraftResumedProcessed: () => setState(() => _resumingDraft = null),
        onViewDrafts: () => setState(() => _viewMode = 'drafts'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 56,
        leading: _viewMode != 'stream'
            ? IconButton(
                onPressed: () => setState(() => _viewMode = 'stream'),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : IconButton(
                onPressed: () => _showAestheticMenu(context),
                icon: const Icon(Icons.menu_rounded),
              ),
        title: Text(
          _viewMode == 'archive'
              ? 'Archive'
              : _viewMode == 'prompts'
                  ? 'Prompts'
                  : _viewMode == 'drafts'
                      ? 'Drafts'
                      : 'Mindstream',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }

  void _showAestheticMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(isDark ? 0.6 : 0.35),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.5,
              ),
            ),
          ),
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Header / Brand Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_rounded,
                      color: activeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Menu',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Options cards
              _buildMenuItem(
                context: context,
                icon: Icons.history_rounded,
                title: 'Archive History',
                subtitle: 'View your recorded mindstreams',
                color: isDark ? AppColors.textDark : AppColors.textLight,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _viewMode = 'archive');
                },
              ),
              const SizedBox(height: 12),

              _buildMenuItem(
                context: context,
                icon: Icons.edit_note_rounded,
                title: 'Drafts Library',
                subtitle: 'Resume or delete saved drafts',
                color: isDark ? AppColors.textDark : AppColors.textLight,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _viewMode = 'drafts');
                },
              ),
              const SizedBox(height: 12),
              
              _buildMenuItem(
                context: context,
                icon: Icons.lightbulb_outline_rounded,
                title: 'Prompts Library',
                subtitle: 'Select writing & thinking prompts',
                color: _selectedPrompt != null ? activeColor : (isDark ? AppColors.textDark : AppColors.textLight),
                iconColor: _selectedPrompt != null ? activeColor : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _viewMode = 'prompts');
                },
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              _buildMenuItem(
                context: context,
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out of your session',
                color: AppColors.error,
                iconColor: AppColors.error,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.error.withOpacity(0.05)
                : (isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDestructive
                  ? AppColors.error.withOpacity(0.1)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgDark : AppColors.bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? (isDark ? AppColors.textDark2 : AppColors.textLight2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
