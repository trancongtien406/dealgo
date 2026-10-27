import { HttpException } from '@nestjs/common';

export type VoiceErrorCode =
  | 'VOICE_FORBIDDEN'
  | 'VOICE_WINDOW_CLOSED'
  | 'VOICE_UNAVAILABLE'
  | 'VOICE_DISABLED'
  | 'VOICE_NOT_FOUND'
  | 'VOICE_NO_COUNTERPART'
  | 'VOICE_BUSY'
  | 'VOICE_CALL_NOT_FOUND'
  | 'VOICE_CALL_NOT_RINGING';

const MESSAGES: Record<VoiceErrorCode, { status: number; message: string }> = {
  VOICE_FORBIDDEN: { status: 403, message: 'Not a participant of this call' },
  VOICE_WINDOW_CLOSED: {
    status: 403,
    message: 'Calls are only available while the ride or order is in progress',
  },
  VOICE_UNAVAILABLE: { status: 503, message: 'Voice provider is not configured' },
  VOICE_DISABLED: { status: 403, message: 'In-app calls are turned off' },
  VOICE_NOT_FOUND: { status: 404, message: 'Transaction not found' },
  VOICE_NO_COUNTERPART: { status: 409, message: 'No driver is assigned yet' },
  VOICE_BUSY: { status: 409, message: 'A call is already in progress for this transaction' },
  VOICE_CALL_NOT_FOUND: { status: 404, message: 'Call not found' },
  VOICE_CALL_NOT_RINGING: { status: 409, message: 'The call is no longer ringing' },
};

export function voiceError(code: VoiceErrorCode): HttpException {
  const meta = MESSAGES[code];
  return new HttpException({ message: meta.message, errorCode: code }, meta.status);
}
