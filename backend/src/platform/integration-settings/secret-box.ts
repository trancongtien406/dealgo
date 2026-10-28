import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

/**
 * At-rest encryption for Admin-managed integration credentials (email provider, map keys).
 * AES-256-GCM with SECRETS_ENCRYPTION_KEY (base64, 32 bytes); envelope base64(iv[12] | tag[16] | ct).
 * The integration kind is bound as AAD so an envelope cannot be moved to another row.
 */
export class SecretBoxError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SecretBoxError';
  }
}

const IV_BYTES = 12;
const TAG_BYTES = 16;

export class SecretBox {
  private readonly key: Buffer;

  constructor(base64Key: string) {
    const key = Buffer.from(base64Key.trim(), 'base64');
    if (key.length !== 32) {
      throw new SecretBoxError('SECRETS_ENCRYPTION_KEY must be base64 of exactly 32 bytes');
    }
    this.key = key;
  }

  seal(plaintext: string, aad: string): string {
    const iv = randomBytes(IV_BYTES);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    cipher.setAAD(Buffer.from(aad, 'utf8'));
    const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), ct]).toString('base64');
  }

  open(envelope: string, aad: string): string {
    const raw = Buffer.from(envelope, 'base64');
    if (raw.length < IV_BYTES + TAG_BYTES) {
      throw new SecretBoxError('secret envelope too short');
    }
    const decipher = createDecipheriv('aes-256-gcm', this.key, raw.subarray(0, IV_BYTES));
    decipher.setAAD(Buffer.from(aad, 'utf8'));
    decipher.setAuthTag(raw.subarray(IV_BYTES, IV_BYTES + TAG_BYTES));
    try {
      return Buffer.concat([decipher.update(raw.subarray(IV_BYTES + TAG_BYTES)), decipher.final()]).toString('utf8');
    } catch {
      throw new SecretBoxError('secret envelope failed authentication (wrong SECRETS_ENCRYPTION_KEY?)');
    }
  }
}
