export interface DatabasePing {
  ping(): Promise<boolean>;
}

export const DATABASE_PING = Symbol('DATABASE_PING');
