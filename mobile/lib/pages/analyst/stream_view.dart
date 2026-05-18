import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/api/api_client.dart';
import '../../core/api/recordings_api.dart';
import '../../core/models/prompt.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/mindstream_aura.dart';
import '../../widgets/stat_chip.dart';

class StreamView extends ConsumerStatefulWidget {
  final Prompt? selectedPrompt;
  final VoidCallback onClearPrompt;

  const StreamView({
    super.key,
    required this.selectedPrompt,
    required this.onClearPrompt,
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
  double _soundLevel = 0.0;

  // Text Mode Controller
  final _textController = TextEditingController();
  bool _hasSubmittedText = false;

  // Recording State & Timer
  Timer? _timer;
  Timer? _mockSpeechTimer;
  int _durationSecs = 0;
  bool _expanded = false;
  bool _saving = false;
  String _saveStatus = 'idle'; // 'idle' | 'saving' | 'done'
  String? _saveError;

  @override
  void dispose() {
    _timer?.cancel();
    _mockSpeechTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceToggle() async {
    if (_isListening) {
      _stopListening();
    } else {
      await _startListening();
    }
  }

  void _startMockListening() {
    print("[SpeechToText] Initiating Simulator Mock Speech Synthesis...");
    setState(() {
      _isListening = true;
      _isLoadingSpeech = false;
      _saveStatus = 'idle';
      _saveError = null;
      _expanded = false;
      _liveTranscript = '';
      _soundLevel = 0.0;
      _durationSecs = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _durationSecs++);
    });

    final words = [
      "We", "are", "seeing", "strong", "secular", "headwinds", "in", 
      "high-growth", "cloud", "infrastructure,", "suggesting", "a", "near-term", 
      "defensive", "pivot", "to", "value", "and", "utilities", "due", "to", 
      "sticky", "inflation", "and", "rising", "capital", "expenditure."
    ];

    int index = 0;
    _mockSpeechTimer?.cancel();
    _mockSpeechTimer = Timer.periodic(const Duration(milliseconds: 380), (timer) {
      if (index < words.length && _isListening) {
        setState(() {
          _liveTranscript += (_liveTranscript.isEmpty ? "" : " ") + words[index];
          _soundLevel = (index % 2 == 0) ? 0.75 : 0.15;
          index++;
        });
      } else {
        _mockSpeechTimer?.cancel();
        setState(() {
          _soundLevel = 0.0;
        });
      }
    });
  }

  Future<void> _startListening() async {
    print("[SpeechToText] Requesting microphone and speech recognition permissions...");
    setState(() {
      _isLoadingSpeech = true;
      _saveStatus = 'idle';
      _saveError = null;
      _expanded = false;
      _liveTranscript = '';
      _soundLevel = 0.0;
    });

    final micPerm = await Permission.microphone.request();
    
    print("[SpeechToText] Mic permission status: $micPerm");
    
    if (!micPerm.isGranted) {
      setState(() {
        _isLoadingSpeech = false;
        _saveError = 'Microphone permission is required';
      });
      return;
    }

    print("[SpeechToText] Initializing speech engine...");
    bool available = await _speech.initialize(
      onError: (val) {
        print("[SpeechToText] onError callback: msg='${val.errorMsg}', permanent=${val.permanent}");
        setState(() {
          _isListening = false;
          _isLoadingSpeech = false;
          _saveError = 'Speech error: ${val.errorMsg} (iOS Simulators may require physical device or downloaded Voices)';
        });
      },
      onStatus: (val) {
        print("[SpeechToText] onStatus callback: status='$val'");
        if (val == 'notListening') {
          setState(() {
            _isListening = false;
            _timer?.cancel();
          });
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
            _liveTranscript = val.recognizedWords;
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
        _saveError = 'Speech recognition is unavailable on this device/simulator';
      });
    }
  }

  void _stopListening() {
    print("[SpeechToText] Stopping voice capturing...");
    _speech.stop();
    _timer?.cancel();
    _mockSpeechTimer?.cancel();
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
        ? (!_isListening && _liveTranscript.trim().isNotEmpty)
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
                            onTap: _isLoadingSpeech
                                ? null
                                : () {
                                    if (_mockSpeechTimer != null && _mockSpeechTimer!.isActive) {
                                      _stopListening();
                                    } else {
                                      _handleVoiceToggle();
                                    }
                                  },
                            child: SizedBox(
                              width: 240,
                              height: 240,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  MindstreamAura(
                                    isActive: _isListening,
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
                                      else if (_isListening)
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
                          if (_saveError != null && (_saveError!.contains('Speech') || _saveError!.contains('Simulator'))) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _startMockListening,
                              icon: const Icon(Icons.auto_awesome, color: AppColors.violet, size: 14),
                              label: const Text('Simulate Voice Input'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.violet,
                                side: const BorderSide(color: AppColors.violet),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              // Minimal Selected Prompt Context Chip
              if (widget.selectedPrompt != null && !_isListening && !hasTranscript)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.violet,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.selectedPrompt!.title,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.textDark2 : AppColors.textLight2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onClearPrompt,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: isDark ? AppColors.textDark3 : AppColors.textLight3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
