import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/api/api_client.dart';
import '../../core/api/recordings_api.dart';
import '../../core/api/prompts_api.dart';
import '../../core/models/prompt.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/mindstream_aura.dart';
import '../../widgets/stat_chip.dart';

class StreamView extends ConsumerStatefulWidget {
  final Prompt? selectedPrompt;
  final VoidCallback onClearPrompt;
  final ValueChanged<Prompt?>? onPromptSelected;

  const StreamView({
    super.key,
    required this.selectedPrompt,
    required this.onClearPrompt,
    this.onPromptSelected,
  });

  @override
  ConsumerState<StreamView> createState() => _StreamViewState();
}

class _StreamViewState extends ConsumerState<StreamView> {
  // Mode toggle: 'voice' or 'text'
  String _inputMode = 'voice';

  // Speech to Text (Native on-device)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isLoadingSpeech = false;
  String _liveTranscript = '';
  String _accumulatedTranscript = '';
  bool _manuallyStopped = false;
  bool _recordingSessionActive = false;
  double _soundLevel = 0.0;

  // Text Mode Controller
  final _textController = TextEditingController();
  bool _hasSubmittedText = false;
  bool _showPromptNudge = true;

  // Recording State & Timer
  Timer? _timer;
  int _durationSecs = 0;
  bool _expanded = false;
  bool _saving = false;
  String _saveStatus = 'idle'; // 'idle' | 'saving' | 'done'
  String? _saveError;

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _handleVoiceToggle() async {
    if (_recordingSessionActive) {
      _stopListening();
    } else {
      await _startListening();
    }
  }



  Future<void> _startListening() async {
    print("[SpeechToText] Requesting microphone and speech recognition permissions...");
    setState(() {
      _isLoadingSpeech = true;
      _recordingSessionActive = true;
      _saveStatus = 'idle';
      _saveError = null;
      _expanded = false;
      _liveTranscript = '';
      _accumulatedTranscript = '';
      _manuallyStopped = false;
      _soundLevel = 0.0;
    });

    final micPerm = await Permission.microphone.request();
    
    print("[SpeechToText] Mic permission status: $micPerm");
    
    if (!micPerm.isGranted) {
      setState(() {
        _isLoadingSpeech = false;
        _recordingSessionActive = false;
        _saveError = 'Microphone permission is required';
      });
      return;
    }

    print("[SpeechToText] Initializing speech engine...");
    bool available = await _speech.initialize(
      onError: (val) {
        print("[SpeechToText] onError callback: msg='${val.errorMsg}', permanent=${val.permanent}");
        
        // Ignore native silence timeouts or no-match errors, as they are handled 
        // gracefully by our background auto-recovery loop.
        if (val.errorMsg == 'error_speech_timeout' || 
            val.errorMsg == 'error_no_match' || 
            val.errorMsg == 'error_busy' ||
            val.errorMsg.contains('timeout')) {
          return;
        }

        setState(() {
          _isListening = false;
          _isLoadingSpeech = false;
          _saveError = 'Speech error: ${val.errorMsg}';
        });
      },
      onStatus: (val) {
        print("[SpeechToText] onStatus callback: status='$val'");
        if (val == 'notListening') {
          if (!_manuallyStopped) {
            print("[SpeechToText] Auto-cutoff detected. Scheduling restore in 400ms...");
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted && !_manuallyStopped) {
                _resumeListening();
              }
            });
          } else {
            setState(() {
              _isListening = false;
              _timer?.cancel();
            });
          }
        }
      },
    );

    print("[SpeechToText] Speech engine initialized. Available: $available");

    if (available) {
      setState(() {
        _isListening = true;
        _isLoadingSpeech = false;
        _durationSecs = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _durationSecs++);
      });

      print("[SpeechToText] Beginning active voice capturing...");
      await _speech.listen(
        onResult: (val) {
          print("[SpeechToText] onResult callback: '${val.recognizedWords}', final=${val.finalResult}");
          setState(() {
            String currentWords = val.recognizedWords;
            if (_accumulatedTranscript.isNotEmpty) {
              _liveTranscript = _accumulatedTranscript + (currentWords.isEmpty ? "" : " " + currentWords);
            } else {
              _liveTranscript = currentWords;
            }
          });
        },
        onSoundLevelChange: (level) {
          setState(() {
            double normalized = (level + 2.0) / 10.0;
            _soundLevel = normalized.clamp(0.0, 1.0);
          });
        },
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 10),
      );
    } else {
      setState(() {
        _isLoadingSpeech = false;
        _recordingSessionActive = false;
        _saveError = 'Speech recognition is unavailable on this device/simulator';
      });
    }
  }

  Future<void> _resumeListening() async {
    if (_manuallyStopped || !_recordingSessionActive) return;
    if (_speech.isListening) {
      print("[SpeechToText] Speech engine is already actively listening, skipping duplicate resume.");
      return;
    }
    print("[SpeechToText] Resuming active voice capturing session...");
    
    // Accumulate the current transcript so it isn't lost on restart
    if (_liveTranscript.trim().isNotEmpty) {
      _accumulatedTranscript = _liveTranscript.trim();
    }
    
    try {
      await _speech.listen(
        onResult: (val) {
          print("[SpeechToText] onResult callback (resume): '${val.recognizedWords}', final=${val.finalResult}");
          setState(() {
            String currentWords = val.recognizedWords;
            if (_accumulatedTranscript.isNotEmpty) {
              _liveTranscript = _accumulatedTranscript + (currentWords.isEmpty ? "" : " " + currentWords);
            } else {
              _liveTranscript = currentWords;
            }
          });
        },
        onSoundLevelChange: (level) {
          setState(() {
            double normalized = (level + 2.0) / 10.0;
            _soundLevel = normalized.clamp(0.0, 1.0);
          });
        },
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 10),
      );
      setState(() {
        _isListening = true;
      });
    } catch (e) {
      print("[SpeechToText] Error resuming listener: $e");
    }
  }

  void _stopListening() {
    print("[SpeechToText] Stopping voice capturing...");
    _manuallyStopped = true;
    _recordingSessionActive = false;
    _speech.stop();
    _timer?.cancel();
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
    });
  }

  Future<void> _handleSave() async {
    final transcript = _inputMode == 'voice' ? _liveTranscript : _textController.text;
    if (transcript.trim().isEmpty) return;

    setState(() {
      _saving = true;
      _saveStatus = 'saving';
      _saveError = null;
    });

    try {
      // Mindstream web uploads audio, but let's replicate with simple text-only or raw local record mapping.
      // For mobile native STT we save it directly to Mindstream's recordings table.
      await RecordingsApi.save(
        type: widget.selectedPrompt != null ? 'prompted' : 'freeform',
        promptId: widget.selectedPrompt?.id,
        transcript: transcript.trim(),
        durationSecs: _inputMode == 'voice' ? _durationSecs : 0,
        wordCount: _wordCount(transcript),
      );

      setState(() {
        _saveStatus = 'done';
      });

      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            if (_inputMode == 'voice') {
              _liveTranscript = '';
            } else {
              _textController.clear();
              _hasSubmittedText = false;
            }
            _saveStatus = 'idle';
            _expanded = false;
          });
          widget.onClearPrompt();
        }
      });
    } catch (e) {
      setState(() {
        _saveError = extractError(e);
        _saveStatus = 'idle';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  String _fmtDuration(int s) {
    final minutes = (s / 60).floor().toString().padLeft(2, '0');
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = _inputMode == 'voice' ? _liveTranscript : _textController.text;
    final hasTranscript = _inputMode == 'voice'
        ? (!_recordingSessionActive && _liveTranscript.trim().isNotEmpty)
        : _hasSubmittedText;

    return Column(
      children: [
        // Mode Selector: Voice / Text segment
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeButton(
                  icon: Icons.mic_none_outlined,
                  isSelected: _inputMode == 'voice',
                  onTap: () {
                    setState(() {
                      _inputMode = 'voice';
                      _hasSubmittedText = false;
                    });
                  },
                ),
                _ModeButton(
                  icon: Icons.edit_note_outlined,
                  isSelected: _inputMode == 'text',
                  onTap: () {
                    setState(() {
                      _inputMode = 'text';
                      _hasSubmittedText = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Main Orb / Write Card capture space
        Expanded(
          child: Center(
            child: _inputMode == 'text' && !_hasSubmittedText
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark.withValues(alpha: 0.65)
                            : AppColors.surfaceLight.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                hintText: 'Write your mindstream down...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                fillColor: Colors.transparent,
                              ),
                              style: GoogleFonts.inter(
                                height: 1.6,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              ),
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _textController,
                                builder: (_, value, __) {
                                  return StatChip('${_wordCount(value.text)} words');
                                },
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (_textController.text.trim().isNotEmpty) {
                                    setState(() => _hasSubmittedText = true);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                child: const Text('Done Writing'),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  )
                : _inputMode == 'voice' && !hasTranscript
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _isLoadingSpeech ? null : _handleVoiceToggle,
                            child: SizedBox(
                              width: 240,
                              height: 240,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  MindstreamAura(
                                    isActive: _recordingSessionActive,
                                    isLoading: _isLoadingSpeech,
                                    amplitude: _soundLevel,
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isLoadingSpeech)
                                        Text(
                                          'Starting…',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                                          ),
                                        )
                                      else if (_recordingSessionActive)
                                        Text(
                                          'Tap to stop',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                                          ),
                                        )
                                      else
                                        Text(
                                          'Tap to speak',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                                          ),
                                        )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                          if (_saveError != null) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _saveError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
          ),
        ),

        // Subtitle / Prompt chip / Stopped Summary card zone
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dynamic Prompts Selection / Selected display
              if (!hasTranscript) ...[
                if (widget.selectedPrompt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.teal : AppColors.tealDark).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? AppColors.teal : AppColors.tealDark).withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.psychology_rounded,
                            color: isDark ? AppColors.teal : AppColors.tealDark,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Prompt: ${widget.selectedPrompt!.title}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: widget.onClearPrompt,
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_showPromptNudge && !_recordingSessionActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark2.withOpacity(0.8) : AppColors.surfaceLight2.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _showPromptSelectorBottomSheet(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: AppColors.violet,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Respond to a PM Prompt',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.textDark : AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 14,
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _showPromptNudge = false),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              // Live voice recognition interim text
              if (_inputMode == 'voice' && _isListening)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _liveTranscript.isEmpty ? 'Listening...' : _liveTranscript,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.6,
                      color: isDark
                          ? AppColors.textDark.withValues(alpha: 0.8)
                          : AppColors.textLight.withValues(alpha: 0.8),
                    ),
                  ),
                ),

              // Saved/Finished Transcript Actions Card
              if (hasTranscript)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark.withValues(alpha: 0.65)
                        : AppColors.surfaceLight.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          StatChip('${_wordCount(text)}w'),
                          if (_inputMode == 'voice') ...[
                            const SizedBox(width: 8),
                            StatChip(_fmtDuration(_durationSecs)),
                          ],
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(() => _expanded = !_expanded),
                            icon: Icon(_expanded ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                            label: Text(_expanded ? 'Hide text' : 'View text'),
                          )
                        ],
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          width: double.infinity,
                          child: SingleChildScrollView(
                            child: Text(
                              text,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.6,
                                color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      if (_saveStatus == 'done')
                        Center(
                          child: Text(
                            'Saved',
                            style: GoogleFonts.inter(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else ...[
                        if (_saveError != null) ...[
                          Text(
                            _saveError!,
                            style: GoogleFonts.inter(color: AppColors.error, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () {
                                        setState(() {
                                          if (_inputMode == 'voice') {
                                            _liveTranscript = '';
                                          } else {
                                            _textController.clear();
                                            _hasSubmittedText = false;
                                          }
                                          _saveStatus = 'idle';
                                          _expanded = false;
                                        });
                                      },
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('Discard'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _handleSave,
                                icon: _saving
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.save_outlined, size: 16),
                                label: Text(_saveStatus == 'saving' ? 'Saving…' : 'Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPromptSelectorBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(isDark ? 0.6 : 0.35),
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<List<Prompt>>(
          future: PromptsApi.list(),
          builder: (context, snapshot) {
            Widget body;
            if (snapshot.connectionState == ConnectionState.waiting) {
              body = const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (snapshot.hasError) {
              body = Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.inter(color: AppColors.error),
                  ),
                ),
              );
            } else {
              final active = (snapshot.data ?? []).where((p) => p.isActive).toList();
              if (active.isEmpty) {
                body = Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No active PM research prompts right now.',
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                      ),
                    ),
                  ),
                );
              } else {
                body = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: active.length,
                    itemBuilder: (context, index) {
                      final p = active[index];
                      final isSelected = widget.selectedPrompt?.id == p.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            if (widget.onPromptSelected != null) {
                              widget.onPromptSelected!(isSelected ? null : p);
                            }
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? activeColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                width: isSelected ? 1.5 : 1,
                              ),
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.textDark : AppColors.textLight,
                                        ),
                                      ),
                                      if (p.description != null && p.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          p.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.check_circle_rounded, color: activeColor, size: 20),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark.withOpacity(0.96) : AppColors.surfaceLight.withOpacity(0.96),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: activeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          color: activeColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Select PM Research Prompt',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textDark : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  body,
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.teal : AppColors.tealDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected
              ? activeColor
              : (isDark ? AppColors.textDark3 : AppColors.textLight3),
        ),
      ),
    );
  }
}
