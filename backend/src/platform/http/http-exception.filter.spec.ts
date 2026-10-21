import {
  ArgumentsHost,
  BadRequestException,
  HttpException,
  NotFoundException,
} from '@nestjs/common';
import { HttpExceptionFilter } from './http-exception.filter.js';

function createHost(path: string, requestIdHeader?: string) {
  const json = vi.fn();
  const status = vi.fn().mockReturnValue({ json });
  const setHeader = vi.fn();
  const host = {
    switchToHttp: () => ({
      getResponse: () => ({ status, setHeader }),
      getRequest: () => ({
        url: path,
        originalUrl: path,
        headers: requestIdHeader ? { 'x-request-id': requestIdHeader } : {},
      }),
    }),
  } as unknown as ArgumentsHost;
  return { host, status, json, setHeader };
}

describe('HttpExceptionFilter', () => {
  const filter = new HttpExceptionFilter();

  it('returns the error envelope for an HttpException', () => {
    const { host, status, json, setHeader } = createHost('/missing', 'req-abc-12345');

    filter.catch(new NotFoundException('Missing'), host);

    expect(status).toHaveBeenCalledWith(404);
    expect(setHeader).toHaveBeenCalledWith('x-request-id', 'req-abc-12345');
    const body = json.mock.calls[0]?.[0] as Record<string, unknown>;
    expect(body).toMatchObject({
      success: false,
      statusCode: 404,
      message: 'Missing',
      errorCode: 'NOT_FOUND',
      path: '/missing',
      requestId: 'req-abc-12345',
    });
    expect(body.timestamp).toEqual(expect.any(String));
    expect(body).not.toHaveProperty('stack');
    expect(body).not.toHaveProperty('details');
  });

  it('passes through a details object attached by the thrower', () => {
    const { host, json } = createHost('/v1/auth/email/login');

    filter.catch(
      new HttpException(
        { message: 'Not verified', errorCode: 'AUTH_EMAIL_NOT_VERIFIED', details: { challengeId: 'c1' } },
        403,
      ),
      host,
    );

    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 403,
        errorCode: 'AUTH_EMAIL_NOT_VERIFIED',
        details: { challengeId: 'c1' },
      }),
    );
  });

  it('uses VALIDATION_ERROR when the message is a list of field errors', () => {
    const { host, json } = createHost('/orders');

    filter.catch(new BadRequestException(['name must be a string']), host);

    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        statusCode: 400,
        message: 'name must be a string',
        errorCode: 'VALIDATION_ERROR',
        path: '/orders',
      }),
    );
  });

  it('hides internal error details from the client and redacts secrets from logger', () => {
    const { host, status, json } = createHost('/health');
    const loggerErrorSpy = vi.spyOn((filter as unknown as { logger: { error: (...args: unknown[]) => void } }).logger, 'error');

    filter.catch(new Error('password=secret SELECT * FROM users postgresql://admin:supersecret@localhost:5432/db'), host);

    expect(status).toHaveBeenCalledWith(500);
    const body = json.mock.calls[0]?.[0] as Record<string, unknown>;
    expect(body).toMatchObject({
      success: false,
      statusCode: 500,
      message: 'Internal server error',
      errorCode: 'INTERNAL_SERVER_ERROR',
      path: '/health',
    });
    expect(JSON.stringify(body)).not.toContain('secret');
    expect(JSON.stringify(body)).not.toContain('supersecret');
    expect(body).not.toHaveProperty('stack');

    expect(loggerErrorSpy).toHaveBeenCalled();
    const [loggedMsg, loggedStack] = loggerErrorSpy.mock.calls[0] ?? [];
    const msgStr = typeof loggedMsg === 'string' ? loggedMsg : '';
    expect(msgStr).not.toContain('secret');
    expect(msgStr).not.toContain('supersecret');
    expect(msgStr).toContain('password=[REDACTED]');
    expect(msgStr).toContain('postgresql://admin:[REDACTED]@localhost:5432/db');
    if (typeof loggedStack === 'string') {
      expect(loggedStack).not.toContain('supersecret');
    }

    loggerErrorSpy.mockRestore();
  });
});
