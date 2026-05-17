import { useState, useRef, useCallback } from 'react';
import * as speechsdk from 'microsoft-cognitiveservices-speech-sdk';
import { getSpeechToken } from '../services/api';

export interface TranscriptEntry {
  id: string;
  text: string;
  timestamp: Date;
}

interface UseSpeechReturn {
  isListening: boolean;
  finalTranscript: string;
  interimText: string;
  entries: TranscriptEntry[];
  error: string | null;
  startListening: () => Promise<void>;
  stopListening: () => void;
  clearTranscript: () => void;
}

export const useSpeech = (): UseSpeechReturn => {
  const [isListening, setIsListening] = useState(false);
  const [finalTranscript, setFinalTranscript] = useState('');
  const [interimText, setInterimText] = useState('');
  const [entries, setEntries] = useState<TranscriptEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const recognizerRef = useRef<speechsdk.SpeechRecognizer | null>(null);

  const startListening = useCallback(async () => {
    setError(null);
    try {
      // Auth-gated speech token fetch
      const { token, region } = await getSpeechToken();

      const speechConfig = speechsdk.SpeechConfig.fromAuthorizationToken(token, region);
      speechConfig.speechRecognitionLanguage = 'en-US';
      speechConfig.enableDictation();

      const audioConfig = speechsdk.AudioConfig.fromDefaultMicrophoneInput();
      const recognizer = new speechsdk.SpeechRecognizer(speechConfig, audioConfig);
      recognizerRef.current = recognizer;

      recognizer.recognizing = (_s, e) => setInterimText(e.result.text);

      recognizer.recognized = (_s, e) => {
        if (e.result.reason === speechsdk.ResultReason.RecognizedSpeech && e.result.text) {
          const entry: TranscriptEntry = {
            id: crypto.randomUUID(),
            text: e.result.text,
            timestamp: new Date(),
          };
          setEntries(prev => [...prev, entry]);
          setFinalTranscript(prev => prev + (prev ? ' ' : '') + e.result.text);
          setInterimText('');
        }
      };

      recognizer.canceled = (_s, e) => {
        if (e.reason === speechsdk.CancellationReason.Error) {
          setError(`Transcription error: ${e.errorDetails}`);
        }
        stopListening();
      };

      recognizer.sessionStopped = () => setIsListening(false);

      recognizer.startContinuousRecognitionAsync(
        () => setIsListening(true),
        (err) => { setError(`Could not start: ${err}`); setIsListening(false); }
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Could not connect to transcription service.';
      setError(msg);
    }
  }, []);

  const stopListening = useCallback(() => {
    if (recognizerRef.current) {
      recognizerRef.current.stopContinuousRecognitionAsync(
        () => {
          setIsListening(false);
          setInterimText('');
          recognizerRef.current?.close();
          recognizerRef.current = null;
        },
        (err) => console.error('[useSpeech] stop error:', err)
      );
    }
  }, []);

  const clearTranscript = useCallback(() => {
    setFinalTranscript('');
    setInterimText('');
    setEntries([]);
  }, []);

  return { isListening, finalTranscript, interimText, entries, error, startListening, stopListening, clearTranscript };
};
