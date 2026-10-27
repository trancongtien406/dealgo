import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

/**
 * At-rest encryption for chat message bodies (AES-256-GCM, Node crypto).
 * Envelope stored in `chat_messages.body_ciphertext`:
 *   base64(iv[12] | authTag[16] | ciphertext), with `key_version` in its own column.
 * The message id + thread id are bound as AAD so ciphertexts cannot be swapped between rows.
 * DRAFT policy: server-side encryption (not E2E); see docs/09-operations/chat-encryption-keys.md.
 */
export type ChatEncryptedBody = { ciphertext: string; keyVersion: number };

export class ChatCipherError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ChatCipherError';
  }
}

const IV_BYTES = 12;
const TAG_BYTES = 16;

export class ChatCipher {
  private readonly keys: Map<number, Buffer>;

  constructor(
    private readonly currentVersion: number,
    keys: Map<number, Buffer>,
  ) {
    for (const [version, key] of keys) {
      if (key.length !== 32) {
        throw new ChatCipherError(`chat key v${version} must be 32 bytes`);
      }
    }
    if (!keys.has(currentVersion)) {
      throw new ChatCipherError('current chat key version has no key');
    }
    this.keys = keys;
  }

  get version(): number {
    return this.currentVersion;
  }

  encrypt(plaintext: string, aad: string): ChatEncryptedBody {
    const key = this.keys.get(this.currentVersion)!;
    const iv = randomBytes(IV_BYTES);
    const cipher = createCipheriv('aes-256-gcm', key, iv);
    cipher.setAAD(Buffer.from(aad, 'utf8'));
    const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return {
      ciphertext: Buffer.concat([iv, tag, ct]).toString('base64'),
      keyVersion: this.currentVersion,
    };
  }

  decrypt(payload: ChatEncryptedBody, aad: string): string {
    const key = this.keys.get(payload.keyVersion);
    if (!key) {
      throw new ChatCipherError(`no chat key for version ${payload.keyVersion}`);
    }
    const raw = Buffer.from(payload.ciphertext, 'base64');
    if (raw.length < IV_BYTES + TAG_BYTES) {
      throw new ChatCipherError('chat ciphertext too short');
    }
    const decipher = createDecipheriv('aes-256-gcm', key, raw.subarray(0, IV_BYTES));
    decipher.setAAD(Buffer.from(aad, 'utf8'));
    decipher.setAuthTag(raw.subarray(IV_BYTES, IV_BYTES + TAG_BYTES));
    try {
      return Buffer.concat([
        decipher.update(raw.subarray(IV_BYTES + TAG_BYTES)),
        decipher.final(),
      ]).toString('utf8');
    } catch {
      throw new ChatCipherError('chat ciphertext failed authentication');
    }
  }
}

export function chatAad(messageId: string, threadId: string): string {
  return `chat:${threadId}:${messageId}`;
}

function parseKey(raw: string, label: string): Buffer {
  const key = Buffer.from(raw.trim(), 'base64');
  if (key.length !== 32) {
    throw new ChatCipherError(`${label} must be base64 of exactly 32 bytes`);
  }
  return key;
}

/**
 * CHAT_ENCRYPTION_KEY            base64 32-byte key (current)
 * CHAT_ENCRYPTION_KEY_VERSION    integer, default 1
 * CHAT_ENCRYPTION_PREVIOUS_KEYS  optional "version:base64,version:base64" kept for decrypt during rotation
 * Returns null when no key is configured (non-production only; production fails in env validation).
 */
export function chatCipherFromEnv(env: {
  CHAT_ENCRYPTION_KEY?: string;
  CHAT_ENCRYPTION_KEY_VERSION?: number;
  CHAT_ENCRYPTION_PREVIOUS_KEYS?: string;
  NODE_ENV?: string;
}): ChatCipher | null {
  const current = env.CHAT_ENCRYPTION_KEY?.trim();
  if (!current) {
    if (env.NODE_ENV === 'production') {
      throw new ChatCipherError('CHAT_ENCRYPTION_KEY is required when NODE_ENV=production');
    }
    return null;
  }
  const version = env.CHAT_ENCRYPTION_KEY_VERSION ?? 1;
  const keys = new Map<number, Buffer>();
  for (const entry of (env.CHAT_ENCRYPTION_PREVIOUS_KEYS ?? '').split(',')) {
    const trimmed = entry.trim();
    if (!trimmed) continue;
    const idx = trimmed.indexOf(':');
    const v = Number(trimmed.slice(0, idx));
    if (idx <= 0 || !Number.isInteger(v) || v <= 0) {
      throw new ChatCipherError('CHAT_ENCRYPTION_PREVIOUS_KEYS entries must be version:base64');
    }
    keys.set(v, parseKey(trimmed.slice(idx + 1), `previous chat key v${v}`));
  }
  keys.set(version, parseKey(current, 'CHAT_ENCRYPTION_KEY'));
  return new ChatCipher(version, keys);
}
