import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { ChatCipher, ChatCipherError, chatAad, chatCipherFromEnv } from './chat-cipher.js';
import { toView } from './chat-prisma.repository.js';

const k1 = randomBytes(32).toString('base64');
const k2 = randomBytes(32).toString('base64');
const aad = chatAad('m1', 't1');

describe('ChatCipher (AES-256-GCM at rest)', () => {
  it('round-trips unicode text with a random IV per message', () => {
    const c = chatCipherFromEnv({ CHAT_ENCRYPTION_KEY: k1 })!;
    const a = c.encrypt('Anh ơi em ở cổng số 2 🚗', aad);
    const b = c.encrypt('Anh ơi em ở cổng số 2 🚗', aad);
    expect(a.ciphertext).not.toEqual(b.ciphertext);
    expect(a.keyVersion).toBe(1);
    expect(c.decrypt(a, aad)).toBe('Anh ơi em ở cổng số 2 🚗');
  });

  it('detects tampering of ciphertext and row binding (AAD)', () => {
    const c = chatCipherFromEnv({ CHAT_ENCRYPTION_KEY: k1 })!;
    const sealed = c.encrypt('hello', aad);
    const raw = Buffer.from(sealed.ciphertext, 'base64');
    raw[raw.length - 1] ^= 0x01;
    expect(() => c.decrypt({ ...sealed, ciphertext: raw.toString('base64') }, aad)).toThrow(ChatCipherError);
    expect(() => c.decrypt(sealed, chatAad('m2', 't1'))).toThrow(ChatCipherError);
  });

  it('rotates keys: new writes use new version, old rows still decrypt', () => {
    const legacy = chatCipherFromEnv({ CHAT_ENCRYPTION_KEY: k1 })!.encrypt('old message', aad);
    const rotated = chatCipherFromEnv({
      CHAT_ENCRYPTION_KEY: k2,
      CHAT_ENCRYPTION_KEY_VERSION: 2,
      CHAT_ENCRYPTION_PREVIOUS_KEYS: `1:${k1}`,
    })!;
    expect(rotated.decrypt(legacy, aad)).toBe('old message');
    expect(rotated.encrypt('new', aad).keyVersion).toBe(2);
    const withoutOld = chatCipherFromEnv({ CHAT_ENCRYPTION_KEY: k2, CHAT_ENCRYPTION_KEY_VERSION: 2 })!;
    expect(() => withoutOld.decrypt(legacy, aad)).toThrow(/no chat key for version 1/);
  });

  it('fails closed when the key is missing in production or malformed', () => {
    expect(() => chatCipherFromEnv({ NODE_ENV: 'production' })).toThrow(/required/);
    expect(chatCipherFromEnv({ NODE_ENV: 'development' })).toBeNull();
    expect(() => chatCipherFromEnv({ CHAT_ENCRYPTION_KEY: 'short' })).toThrow(/32 bytes/);
    expect(() => new ChatCipher(3, new Map())).toThrow(ChatCipherError);
  });

  it('repository view decrypts for readers and refuses encrypted rows without a key', () => {
    const c = chatCipherFromEnv({ CHAT_ENCRYPTION_KEY: k1 })!;
    const sealed = c.encrypt('xin chào', aad);
    const row = { id: 'm1', threadId: 't1', senderUserId: 'u1', body: null,
      bodyCiphertext: sealed.ciphertext, keyVersion: sealed.keyVersion, createdAt: new Date() };
    expect(toView(row, c).body).toBe('xin chào');
    expect(() => toView(row, null)).toThrow(/no chat key/);
    expect(toView({ ...row, body: 'legacy', bodyCiphertext: null, keyVersion: null }, null).body).toBe('legacy');
  });
});
