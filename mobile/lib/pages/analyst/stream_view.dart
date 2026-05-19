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
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/mindstream_aura.dart';
import '../../widgets/stat_chip.dart';

class StreamView extends ConsumerStatefulWidget {
  final Prompt? selectedPrompt;
  final VoidCallback onClearPrompt;
  final ValueChanged<Prompt?>? onPromptSelected;
  final Map<String, dynamic>? resumingDraft;
  final VoidCallback? onDraftResumedProcessed;
  final VoidCallback? onViewDrafts;

  const StreamView({
    super.key,
    required this.selectedPrompt,
    required this.onClearPrompt,
    this.onPromptSelected,
    this.resumingDraft,
    this.onDraftResumedProcessed,
    this.onViewDrafts,
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
  final _voiceEditController = TextEditingController();
  bool _hasSubmittedText = false;
  bool _showPromptNudge = true;

  // Recording State & Timer
  Timer? _timer;
  int _durationSecs = 0;
  bool _expanded = false;
  bool _saving = false;
  String _saveStatus = 'idle'; // 'idle' | 'saving' | 'done'
  String? _saveError;
  List<Map<String, dynamic>> _drafts = [];
  String? _resumingDraftId;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
    if (widget.resumingDraft != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDraftFromMap(widget.resumingDraft!);
        widget.onDraftResumedProcessed?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant StreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resumingDraft != null && widget.resumingDraft != oldWidget.resumingDraft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDraftFromMap(widget.resumingDraft!);
        widget.onDraftResumedProcessed?.call();
      });
    }
  }

  Future<void> _loadDrafts() async {
    final drafts = await SyncService.getDrafts();
    if (mounted) {
      setState(() {
        _drafts = drafts;
      });
    }
  }
  void _loadDraftFromMap(Map<String, dynamic> draft) {
    setState(() {
      _resumingDraftId = draft['id'] as String?;
      _inputMode = draft['type'] == 'prompted' ? 'voice' : ((draft['duration_secs'] as int? ?? 0) > 0 ? 'voice' : 'text');
      final tr = draft['transcript'] as String? ?? '';
      
      if (_inputMode == 'voice') {
        _liveTranscript = tr;
        _accumulatedTranscript = tr;
        _voiceEditController.text = tr;
        _durationSecs = draft['duration_secs'] as int? ?? 0;
      } else {
        _textController.text = tr;
        _hasSubmittedText = true;
      }

      if (draft['prompt_id'] != null) {
        final prompt = Prompt(
          id: draft['prompt_id'] as String,
          title: draft['prompt_title'] as String? ?? 'Prompt',
          status: 'active',
          createdAt: DateTime.now().toIso8601String(),
        );
        widget.onPromptSelected?.call(prompt);
      } else {
        widget.onClearPrompt();
      }
      
      _expanded = true;
      _saveStatus = 'idle';
      _saveError = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    _voiceEditController.dispose();
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
      
      // If we have an existing transcript (e.g. from a draft or a manually stopped session), preserve it.
      if (_voiceEditController.text.isNotEmpty && _liveTranscript.isEmpty) {
        _accumulatedTranscript = _voiceEditController.text;
        _liveTranscript = _accumulatedTranscript;
      } else if (_liveTranscript.isNotEmpty) {
        _accumulatedTranscript = _liveTranscript;
      } else {
        // Only reset duration if it's a completely fresh recording
        _durationSecs = 0;
      }
      
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
    
    _voiceEditController.text = _liveTranscript;
    
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
      _expanded = true; // Auto-expand when stopped
    });
  }

  Future<void> _handleSave() async {
    final transcript = _inputMode == 'voice' ? _voiceEditController.text : _textController.text;
    if (transcript.trim().isEmpty) return;

    setState(() {
      _saving = true;
      _saveStatus = 'saving';
      _saveError = null;
    });

    try {
      await RecordingsApi.save(
        type: widget.selectedPrompt != null ? 'prompted' : 'freeform',
        promptId: widget.selectedPrompt?.id,
        transcript: transcript.trim(),
        durationSecs: _inputMode == 'voice' ? _durationSecs : 0,
        wordCount: _wordCount(transcript),
      );

      if (_resumingDraftId != null) {
        await SyncService.deleteDraftById(_resumingDraftId!);
        _resumingDraftId = null;
        _loadDrafts(); // Refresh drafts list if there is a badge
      }

      setState(() {
        _saveStatus = 'done';
      });

      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            if (_inputMode == 'voice') {
              _liveTranscript = '';
              _accumulatedTranscript = '';
              _voiceEditController.clear();
            } else {
              _textController.clear();
              _hasSubmittedText = false;
            }
            _saveStatus = 'idle';
            _expanded = false;
            _durationSecs = 0;
          });
          widget.onClearPrompt();
        }
      });
    } catch (e) {
      try {
        await SyncService.saveDraft({
          if (_resumingDraftId != null) 'id': _resumingDraftId,
          'type': widget.selectedPrompt != null ? 'prompted' : 'freeform',
          'prompt_id': widget.selectedPrompt?.id,
          'prompt_title': widget.selectedPrompt?.title,
          'transcript': transcript.trim(),
          'duration_secs': _inputMode == 'voice' ? _durationSecs : 0,
          'word_count': _wordCount(transcript),
        });
        
        await _loadDrafts();

        setState(() {
          _saveStatus = 'idle';
        });
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return AlertDialog(
                backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                title: Text(
                'Upload Failed',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              content: Text(
                'Your connection may be unstable. Your recording has been safely saved to Draft Notes.',
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {
                        if (_inputMode == 'voice') {
                          _liveTranscript = '';
                          _accumulatedTranscript = '';
                          _voiceEditController.clear();
                        } else {
                          _textController.clear();
                          _hasSubmittedText = false;
                        }
                        _expanded = false;
                        _durationSecs = 0;
                        _saveError = null;
                      });
                      widget.onClearPrompt();
                    }
                  },
                  child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.violet)),
                ),
              ],
            );
          },
          );
        }
      } catch (syncErr) {
        setState(() {
          _saveError = 'Failed to save online and offline.';
          _saveStatus = 'idle';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleSaveDraft() async {
    final transcript = _inputMode == 'voice' ? _voiceEditController.text : _textController.text;
    if (transcript.trim().isEmpty) return;

    setState(() {
      _saving = true;
      _saveStatus = 'saving';
      _saveError = null;
    });

    try {
      await SyncService.saveDraft({
        if (_resumingDraftId != null) 'id': _resumingDraftId,
        'type': widget.selectedPrompt != null ? 'prompted' : 'freeform',
        'prompt_id': widget.selectedPrompt?.id,
        'prompt_title': widget.selectedPrompt?.title,
        'transcript': transcript.trim(),
        'duration_secs': _inputMode == 'voice' ? _durationSecs : 0,
        'word_count': _wordCount(transcript),
      });
      
      setState(() {
        _saveStatus = 'done';
        _saveError = 'Saved as draft';
      });

      await _loadDrafts();

      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            if (_inputMode == 'voice') {
              _liveTranscript = '';
              _accumulatedTranscript = '';
              _voiceEditController.clear();
            } else {
              _textController.clear();
              _hasSubmittedText = false;
            }
            _saveStatus = 'idle';
            _expanded = false;
            _durationSecs = 0;
            _saveError = null;
          });
          widget.onClearPrompt();
        }
      });
    } catch (syncErr) {
      setState(() {
        _saveError = 'Failed to save draft.';
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

  String _getLastWords(String text, {int count = 6}) {
    if (text.trim().isEmpty) return '';
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= count) return text;
    return '... ${words.sublist(words.length - count).join(' ')}';
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
        if (!hasTranscript)
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
            child: hasTranscript
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit_note_rounded, size: 24, color: isDark ? AppColors.textDark2 : AppColors.textLight2),
                            const SizedBox(width: 12),
                            Text(
                              'Review & Edit',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark2.withValues(alpha: 0.3) : AppColors.surfaceLight2.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                            child: TextField(
                              controller: _inputMode == 'voice' ? _voiceEditController : _textController,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                height: 1.6,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_saveStatus == 'done')
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  _saveError != null ? Icons.edit_note_rounded : Icons.check_circle_outline,
                                  color: _saveError != null ? (isDark ? AppColors.teal : AppColors.tealDark) : AppColors.success,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _saveError ?? 'Saved Successfully',
                                  style: GoogleFonts.inter(
                                    color: _saveError != null ? (isDark ? AppColors.teal : AppColors.tealDark) : AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else ...[
                          if (_saveError != null) ...[
                            Text(
                              _saveError!,
                              style: GoogleFonts.inter(color: AppColors.error, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_inputMode == 'voice') ...[
                            OutlinedButton.icon(
                              onPressed: _saving ? null : () async {
                                await _startListening();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                              ),
                              icon: Icon(Icons.mic_none_outlined, size: 20, color: isDark ? AppColors.textDark : AppColors.textLight),
                              label: Text('Continue Recording', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () {
                                        setState(() {
                                          if (_inputMode == 'voice') {
                                            _liveTranscript = '';
                                            _accumulatedTranscript = '';
                                            _voiceEditController.clear();
                                            _durationSecs = 0;
                                          } else {
                                            _textController.clear();
                                            _hasSubmittedText = false;
                                          }
                                          _saveStatus = 'idle';
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                ),
                                child: Icon(Icons.delete_outline, size: 20, color: isDark ? AppColors.textDark2 : AppColors.textLight2),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : _handleSaveDraft,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                  ),
                                  icon: Icon(Icons.save_as_outlined, size: 18, color: isDark ? AppColors.textDark : AppColors.textLight),
                                  label: Text('Save Draft', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saving ? null : _handleSave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.textDark : AppColors.textLight,
                                    foregroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  icon: _saving
                                      ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? AppColors.bgDark : AppColors.bgLight))
                                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                                  label: Text(_saveStatus == 'saving' ? 'Saving…' : 'Upload', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                : _inputMode == 'text'
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
                    : Column(
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
                      ),
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
                if (_drafts.isNotEmpty && !_recordingSessionActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: widget.onViewDrafts,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark2.withOpacity(0.8) : AppColors.surfaceLight2.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_drafts.length} Unfinished Draft${_drafts.length > 1 ? 's' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textDark : AppColors.textLight,
                                ),
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
                  ),
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
                    _liveTranscript.isEmpty ? 'Listening...' : _getLastWords(_liveTranscript),
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
