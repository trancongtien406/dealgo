import { ConsoleLogger, type LoggerService } from '@nestjs/common';

export type LogFormat = 'text' | 'json';

/** LOG_FORMAT wins; otherwise json in production, text elsewhere (DEC-PROD-054). */
export function resolveLogFormat(source: NodeJS.ProcessEnv = process.env): LogFormat {
  const raw = source.LOG_FORMAT?.trim().toLowerCase();
  if (raw === 'json' || raw === 'text') {
    return raw;
  }
  return source.NODE_ENV === 'production' ? 'json' : 'text';
}

/** Nest logger: one JSON object per line for log shippers, or the default coloured text. */
export function createAppLogger(format: LogFormat = resolveLogFormat()): LoggerService {
  return format === 'json'
    ? new ConsoleLogger({ json: true, colors: false })
    : new ConsoleLogger();
}
