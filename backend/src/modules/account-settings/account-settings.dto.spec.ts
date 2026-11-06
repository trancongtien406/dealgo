import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { describe, expect, it } from 'vitest';
import { ChangePasswordDto } from './account-settings.dto.js';

describe('ChangePasswordDto password minimum length', () => {
  const newPasswordErrors = (newPassword: string) =>
    validateSync(
      plainToInstance(ChangePasswordDto, { currentPassword: 'old-password', newPassword }),
    ).filter((error) => error.property === 'newPassword');

  it('accepts 6 characters', () => {
    expect(newPasswordErrors('123456')).toHaveLength(0);
  });

  it('rejects 5 characters', () => {
    expect(newPasswordErrors('12345').length).toBeGreaterThan(0);
  });
});
