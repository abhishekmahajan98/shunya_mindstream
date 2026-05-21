import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';
import 'session_service.dart';

/// Streams microphone PCM to the backend; transcripts come back over WebSocket.
/// The client never talks to Azure Speech directly.
class SpeechStreamService {
  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<dynamic>? _wsSub;
  bool _active = false;
  DateTime? _lastLevelEmit;

  bool get isActive => _active;

  /// [onTranscript] receives the live line and whether the latest chunk is final.
  /// [onSoundLevel] is derived locally from PCM amplitude (UI only, not sent to Azure).
  Future<void> start({
    required void Function(String liveText, bool isFinal) onTranscript,
    void Function(double level)? onSoundLevel,
    void Function(String message)? onError,
    void Function()? onReady,
  }) async {
    if (_active) return;

    final token = await SessionService.getAccessToken();
    if (token == null) {
      onError?.call('Not signed in');
      return;
    }

    final wsUri = speechStreamWsUri(token);
    debugPrint('[SpeechStream] Connecting to $wsUri');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[SpeechStream] Connect failed: $e');
      onError?.call(
        'Could not connect to speech server. Check network or API_URL.',
      );
      await stop();
      return;
    }

    _active = true;

    _wsSub = _channel!.stream.listen(
      (message) {
        if (message is! String) return;
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          final event = data['event'] as String?;
          switch (event) {
            case 'ready':
              onReady?.call();
            case 'partial':
              final text = data['text'] as String? ?? '';
              if (text.isNotEmpty) onTranscript(text, false);
            case 'final':
              final text = data['text'] as String? ?? '';
              if (text.isNotEmpty) onTranscript(text, true);
            case 'error':
              onError?.call(data['message'] as String? ?? 'Speech error');
              stop();
          }
        } catch (e) {
          debugPrint('[SpeechStream] Bad message: $e');
        }
      },
      onError: (e) {
        debugPrint('[SpeechStream] Stream error: $e');
        onError?.call('Speech connection lost');
        stop();
      },
      onDone: () {
        if (_active) {
          onError?.call('Speech connection closed');
          stop();
        }
      },
    );

    if (!await _recorder.hasPermission()) {
      onError?.call('Microphone permission is required');
      await stop();
      return;
    }

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSub = stream.listen(
        (chunk) {
          if (!_active || _channel == null) return;
          _channel!.sink.add(chunk);
          if (onSoundLevel != null) {
            final now = DateTime.now();
            if (_lastLevelEmit == null ||
                now.difference(_lastLevelEmit!).inMilliseconds >= 33) {
              _lastLevelEmit = now;
              onSoundLevel!(_pcmAmplitude(chunk));
            }
          }
        },
        onError: (e) {
          onError?.call('Microphone error: $e');
          stop();
        },
      );
    } catch (e) {
      onError?.call('Could not start microphone: $e');
      await stop();
    }
  }

  Future<void> stop() async {
    if (!_active && _channel == null && _audioSub == null) return;
    _active = false;

    try {
      _channel?.sink.add(jsonEncode({'action': 'stop'}));
    } catch (_) {}

    await _audioSub?.cancel();
    _audioSub = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    await _wsSub?.cancel();
    _wsSub = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> dispose() => stop();

  /// Maps mic RMS into 0–1 with sensitivity similar to the old speech_to_text
  /// `(level + 2) / 10` curve so MindstreamAura reacts while speaking.
  static double _pcmAmplitude(Uint8List bytes) {
    if (bytes.length < 2) return 0;
    final count = bytes.length ~/ 2;
    final bd = ByteData.sublistView(bytes);
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      final s = bd.getInt16(i * 2, Endian.little).toDouble();
      sum += s * s;
    }
    final rms = math.sqrt(sum / count);
    const minRms = 180.0;
    const maxRms = 9000.0;
    final linear = ((rms - minRms) / (maxRms - minRms)).clamp(0.0, 1.0);
    return math.pow(linear, 0.55).toDouble();
  }
}
