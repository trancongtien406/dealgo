import { BadRequestException } from '@nestjs/common';
import { IsString } from 'class-validator';
import { createValidationPipe } from './create-validation-pipe.js';

class SampleBody {
  @IsString()
  name!: string;
}

describe('createValidationPipe', () => {
  const pipe = createValidationPipe();
  const metadata = { type: 'body' as const, metatype: SampleBody, data: '' };

  it('rejects properties that are not declared on the DTO', async () => {
    await expect(pipe.transform({ name: 'dealgo', extra: true }, metadata)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('keeps declared properties', async () => {
    await expect(pipe.transform({ name: 'dealgo' }, metadata)).resolves.toEqual({ name: 'dealgo' });
  });
});
