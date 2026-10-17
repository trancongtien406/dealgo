import net from 'node:net';
import { Injectable } from '@nestjs/common';

export const REDIS_PROBE = Symbol('REDIS_PROBE');

export interface RedisProbe {
  ping(url: string | undefined, timeoutMs?: number): Promise<boolean>;
}

export function pingRedis(url: string | undefined, timeoutMs = 1000): Promise<boolean> {
  if (!url) {
    return Promise.resolve(false);
  }
  return new Promise((resolve) => {
    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      resolve(false);
      return;
    }

    if (parsed.protocol !== 'redis:' && parsed.protocol !== 'rediss:') {
      resolve(false);
      return;
    }

    const port = parsed.port ? Number.parseInt(parsed.port, 10) : 6379;
    const host = parsed.hostname || '127.0.0.1';

    const socket = new net.Socket();
    let settled = false;

    const cleanup = () => {
      if (!settled) {
        settled = true;
        socket.destroy();
      }
    };

    socket.setTimeout(timeoutMs);
    socket.once('connect', () => {
      cleanup();
      resolve(true);
    });

    socket.once('timeout', () => {
      cleanup();
      resolve(false);
    });

    socket.once('error', () => {
      cleanup();
      resolve(false);
    });

    try {
      socket.connect(port, host);
    } catch {
      cleanup();
      resolve(false);
    }
  });
}

@Injectable()
export class TcpRedisProbe implements RedisProbe {
  ping(url: string, timeoutMs?: number): Promise<boolean> {
    return pingRedis(url, timeoutMs);
  }
}
