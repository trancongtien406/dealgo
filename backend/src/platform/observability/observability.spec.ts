import { ConsoleLogger } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { createAppLogger, resolveLogFormat } from './app-logger.js';
import type { ErrorEvent } from '@sentry/node';
import {
  captureServerError,
  initSentry,
  isExpectedClientError,
  isSentryEnabled,
  scrubSentryEvent,
  scrubText,
  sentryOptionsFromEnv,
} from './sentry.js';
import {
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';

describe('observability', () => {
  it('resolves log format from LOG_FORMAT, else production → json', () => {
    expect(resolveLogFormat({ LOG_FORMAT: 'json' })).toBe('json');
    expect(resolveLogFormat({ NODE_ENV: 'production' })).toBe('json');
    expect(
      resolveLogFormat({ NODE_ENV: 'production', LOG_FORMAT: 'text' }),
    ).toBe('text');
    expect(resolveLogFormat({ NODE_ENV: 'development' })).toBe('text');
  });

  it('json logger writes one JSON object per line', () => {
    const logger = createAppLogger('json') as ConsoleLogger;
    const write = vi
      .spyOn(process.stdout, 'write')
      .mockImplementation(() => true);
    logger.log('hello', 'Ctx');
    const line = String(write.mock.calls[0]?.[0] ?? '');
    write.mockRestore();
    const parsed = JSON.parse(line) as {
      message: string;
      context: string;
      level: string;
    };
    expect(parsed).toMatchObject({
      message: 'hello',
      context: 'Ctx',
      level: 'log',
    });
  });

  it('Sentry is a no-op without a DSN', () => {
    const options = sentryOptionsFromEnv({
      NODE_ENV: 'production',
      SENTRY_TRACES_SAMPLE_RATE: '5',
    });
    expect(options.dsn).toBeUndefined();
    expect(options.tracesSampleRate).toBe(0);
    expect(initSentry(options)).toBe(false);
    expect(isSentryEnabled()).toBe(false);
    expect(() => captureServerError(new Error('x'))).not.toThrow();
  });

  it('Sentry options read release and environment', () => {
    const options = sentryOptionsFromEnv({
      SENTRY_DSN: ' https://k@o1.ingest.us.sentry.io/2 ',
      SENTRY_ENVIRONMENT: 'production',
      SENTRY_RELEASE: '2026.10.27-1930',
      SENTRY_TRACES_SAMPLE_RATE: '0.1',
    });
    expect(options).toMatchObject({
      dsn: 'https://k@o1.ingest.us.sentry.io/2',
      environment: 'production',
      release: '2026.10.27-1930',
      tracesSampleRate: 0.1,
    });
  });

  it('scrubs tokens, secrets, emails, phones and queries', () => {
    const text = scrubText(
      'fail https://api.x/v1/a?token=abc for ana@mail.vn +84901234567 0912345678 ' +
        'Bearer abc.def password=hunter2 eyJhbGciOi.eyJzdWIi.sig',
    );
    expect(text).toBe(
      'fail https://api.x/v1/a for [email] [phone] [phone] bearer [redacted] password=[redacted] [jwt]',
    );
  });

  it('keeps only the user id and drops request details', () => {
    const event = scrubSentryEvent({
      type: undefined,
      user: { id: 'u1', email: 'a@b.vn', ip_address: '1.2.3.4' },
      request: {
        method: 'POST',
        url: 'https://api/v1/x?q=1',
        headers: { authorization: 'Bearer t' },
        cookies: { s: '1' },
        data: { phone: '0901' },
        query_string: 'q=1',
      },
      exception: {
        values: [{ type: 'Error', value: 'otp=123456 for 0901234567' }],
      },
      breadcrumbs: [
        {
          category: 'http',
          data: { url: 'https://a/b?x=1', method: 'GET', body: 'x' },
        },
      ],
    } as ErrorEvent);
    expect(event.user).toEqual({ id: 'u1' });
    expect(event.request).toEqual({ method: 'POST', url: 'https://api/v1/x' });
    expect(event.exception?.values?.[0]?.value).toBe(
      'otp=[redacted] for [phone]',
    );
    expect(event.breadcrumbs?.[0]?.data).toEqual({
      url: 'https://a/b',
      method: 'GET',
    });
  });

  it('expected 4xx are never reported; 5xx are', () => {
    expect(
      isExpectedClientError({
        originalException: new BadRequestException('x'),
      }),
    ).toBe(true);
    expect(
      isExpectedClientError({
        originalException: new InternalServerErrorException(),
      }),
    ).toBe(false);
    expect(
      isExpectedClientError({ originalException: new Error('boom') }),
    ).toBe(false);
  });
});
