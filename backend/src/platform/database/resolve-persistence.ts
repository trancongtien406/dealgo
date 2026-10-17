export class PersistenceMisconfiguredError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PersistenceMisconfiguredError';
  }
}

export type ResolvePersistenceInput<TClient, TRepo> = {
  nodeEnv: string;
  databaseUrl: string | undefined;
  client: TClient | null;
  createMemory: () => TRepo;
  createPrisma: (client: TClient) => TRepo;
};

/**
 * Memory repositories are allowed only in NODE_ENV=test (or when tests override
 * the provider). Missing DATABASE_URL outside test fails startup.
 */
export function resolvePersistenceRepository<TClient, TRepo>(
  input: ResolvePersistenceInput<TClient, TRepo>,
): TRepo {
  if (input.nodeEnv === 'test') {
    if (input.client) {
      return input.createPrisma(input.client);
    }
    return input.createMemory();
  }

  if (!input.databaseUrl || !input.client) {
    throw new PersistenceMisconfiguredError(
      'DATABASE_URL is required when NODE_ENV is not test; memory repositories are disabled',
    );
  }

  return input.createPrisma(input.client);
}
