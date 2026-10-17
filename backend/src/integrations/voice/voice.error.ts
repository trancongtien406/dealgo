import { HttpException } from '@nestjs/common';

export type VoiceErrorCode =
  | 'VOICE_FORBIDDEN'
  | 'VOICE_WINDOW_CLOSED'
  | 'VOICE_UNAVAILABLE'
  | 'VOICE_NOT_FOUND';

const MESSAGES: Record<VoiceErrorCode, { status: number; message: string }> = {
  VOICE_FORBIDDEN: { status: 403, message: 'Not a participant of this conversation' },
  VOICE_WINDOW_CLOSED: {
    status: 403,
    message: 'Contact window is closed for this transaction',
  },
  VOICE_UNAVAILABLE: { status: 503, message: 'Voice provider is not configured' },
  VOICE_NOT_FOUND: { status: 404, message: 'Transaction not found' },
};

export function voiceError(code: VoiceErrorCode): HttpException {
  const meta = MESSAGES[code];
  return new HttpException({ message: meta.message, errorCode: code }, meta.status);
}
