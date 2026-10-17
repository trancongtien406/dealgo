import { randomBytes } from 'node:crypto';
import { Injectable, OnModuleInit } from '@nestjs/common';
import { argon2id, hash as argon2Hash, verify as argon2Verify } from 'argon2';

@Injectable()
export class PasswordHasher implements OnModuleInit {
  private dummyHash = '';

  async onModuleInit(): Promise<void> {
    this.dummyHash = await this.hash(randomBytes(32).toString('base64url'));
  }

  async hash(password: string): Promise<string> {
    return argon2Hash(password, { type: argon2id });
  }

  async verify(hash: string, password: string): Promise<boolean> {
    try {
      return await argon2Verify(hash, password);
    } catch {
      return false;
    }
  }

  // A missing account still runs a hash verify so the response time does not reveal whether the email exists.
  async verifyPresented(storedHash: string | null, password: string): Promise<boolean> {
    if (!this.dummyHash) {
      this.dummyHash = await this.hash(randomBytes(32).toString('base64url'));
    }
    const matches = await this.verify(storedHash ?? this.dummyHash, password);
    return storedHash !== null && matches;
  }
}
