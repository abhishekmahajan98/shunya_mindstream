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

class AnalystHomePage extends ConsumerStatefulWidget {
  const AnalystHomePage({super.key});

  @override
  ConsumerState<AnalystHomePage> createState() => _AnalystHomePageState();
}

class _AnalystHomePageState extends ConsumerState<AnalystHomePage> {
  // 'stream' | 'archive' | 'prompts'
  String _viewMode = 'stream';
  Prompt? _selectedPrompt;

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
    } else {
      body = StreamView(
        selectedPrompt: _selectedPrompt,
        onClearPrompt: () => setState(() => _selectedPrompt = null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: _viewMode != 'stream'
            ? IconButton(
                onPressed: () => setState(() => _viewMode = 'stream'),
                icon: const Icon(Icons.arrow_back),
              )
            : Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _viewMode = 'archive'),
                    icon: const Icon(Icons.history),
                  ),
                ],
              ),
        leadingWidth: _viewMode != 'stream' ? 56 : 96,
        title: _viewMode == 'stream'
            ? Text(
                'Mindstream',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              )
            : const SizedBox.shrink(),
        actions: [
          if (_viewMode == 'stream') ...[
            IconButton(
              onPressed: () => setState(() => _viewMode = 'prompts'),
              icon: Icon(
                Icons.lightbulb_outline,
                color: _selectedPrompt != null
                    ? activeColor
                    : (isDark ? AppColors.textDark : AppColors.textLight),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          IconButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}
