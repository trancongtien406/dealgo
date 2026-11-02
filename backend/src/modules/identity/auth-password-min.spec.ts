import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { describe, expect, it } from 'vitest';
import {
  EmailPasswordLoginDto,
  EmailPasswordRegisterDto,
  PasswordResetConfirmDto,
} from './auth.dto.js';

/** t91u: customer/partner passwords need 6+ characters (was 8). */
describe('password minimum length (t91u)', () => {
  const fieldErrors = (cls: new () => object, body: Record<string, unknown>) =>
    validateSync(plainToInstance(cls, body) as object).filter((e) => e.property === 'password');

  it.each([EmailPasswordRegisterDto, EmailPasswordLoginDto, PasswordResetConfirmDto])(
    '%o accepts 6 characters and rejects 5',
    (cls) => {
      expect(fieldErrors(cls, { email: 'a@dealgo.vn', password: '123456' })).toHaveLength(0);
      expect(fieldErrors(cls, { email: 'a@dealgo.vn', password: '12345' }).length).toBeGreaterThan(0);
    },
  );
});
