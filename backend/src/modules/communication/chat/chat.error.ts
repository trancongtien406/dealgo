import { HttpException } from '@nestjs/common';

export type ChatErrorCode =
  | 'CHAT_FORBIDDEN'
  | 'CHAT_NOT_FOUND'
  | 'CHAT_BODY_INVALID'
  | 'CHAT_UNAVAILABLE'
  | 'CHAT_WINDOW_CLOSED';

const MESSAGES: Record<ChatErrorCode, { status: number; message: string }> = {
  CHAT_FORBIDDEN: { status: 403, message: 'Not a participant of this conversation' },
  CHAT_NOT_FOUND: { status: 404, message: 'Conversation not found' },
  CHAT_BODY_INVALID: { status: 400, message: 'Message body is invalid' },
  CHAT_UNAVAILABLE: { status: 503, message: 'Chat persistence is unavailable' },
  CHAT_WINDOW_CLOSED: {
    status: 403,
    message: 'Contact window is closed for this transaction',
  },
};

export function chatError(code: ChatErrorCode): HttpException {
  const meta = MESSAGES[code];
  return new HttpException(
    { message: meta.message, errorCode: code },
    meta.status,
  );
}
