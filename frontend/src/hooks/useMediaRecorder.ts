import { useRef, useState, useCallback } from 'react';

function getSupportedMimeType(): string {
  const types = [
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/ogg;codecs=opus',
    'audio/ogg',
    'audio/mp4',
  ];
  return types.find(t => MediaRecorder.isTypeSupported(t)) ?? '';
}

export function useMediaRecorder() {
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null);
  const recRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const mimeType = getSupportedMimeType();

  const start = useCallback(async () => {
    setAudioBlob(null);
    chunksRef.current = [];
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const options = mimeType ? { mimeType } : undefined;
      const rec = new MediaRecorder(stream, options);
      recRef.current = rec;

      rec.ondataavailable = e => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      rec.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: mimeType || 'audio/webm' });
        setAudioBlob(blob);
        stream.getTracks().forEach(t => t.stop());
      };
      rec.start(500); // collect chunks every 500ms
    } catch (e) {
      console.warn('[useMediaRecorder] could not start:', e);
    }
  }, [mimeType]);

  const stop = useCallback(() => {
    if (recRef.current && recRef.current.state !== 'inactive') {
      recRef.current.stop();
    }
  }, []);

  const reset = useCallback(() => {
    setAudioBlob(null);
    chunksRef.current = [];
  }, []);

  return { audioBlob, start, stop, reset, mimeType };
}
