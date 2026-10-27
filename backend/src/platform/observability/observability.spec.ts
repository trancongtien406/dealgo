import { ConsoleLogger } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { createAppLogger, resolveLogFormat } from './app-logger.js';
import { captureServerError, initSentry, isSentryEnabled, sentryOptionsFromEnv } from './sentry.js';

describe('observability', () => {
  it('resolves log format from LOG_FORMAT, else production → json', () => {
    expect(resolveLogFormat({ LOG_FORMAT: 'json' })).toBe('json');
    expect(resolveLogFormat({ NODE_ENV: 'production' })).toBe('json');
    expect(resolveLogFormat({ NODE_ENV: 'production', LOG_FORMAT: 'text' })).toBe('text');
    expect(resolveLogFormat({ NODE_ENV: 'development' })).toBe('text');
  });

  it('json logger writes one JSON object per line', () => {
    const logger = createAppLogger('json') as ConsoleLogger;
    const write = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);
    logger.log('hello', 'Ctx');
    const line = String(write.mock.calls[0]?.[0] ?? '');
    write.mockRestore();
    const parsed = JSON.parse(line) as { message: string; context: string; level: string };
    expect(parsed).toMatchObject({ message: 'hello', context: 'Ctx', level: 'log' });
  });

  it('Sentry is a no-op without a DSN', () => {
    const options = sentryOptionsFromEnv({ NODE_ENV: 'production', SENTRY_TRACES_SAMPLE_RATE: '5' });
    expect(options.dsn).toBeUndefined();
    expect(options.tracesSampleRate).toBe(0);
    expect(initSentry(options)).toBe(false);
    expect(isSentryEnabled()).toBe(false);
    expect(() => captureServerError(new Error('x'))).not.toThrow();
  });
});
