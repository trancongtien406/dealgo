import type { Prisma } from '../../generated/prisma/client.js';

/**
 * One transaction-scoped advisory lock per driver for every path that assigns a job
 * (ride select, food claim, food early claim). Held until commit/rollback, so two concurrent
 * assignments for the same driver are serialized and the capacity count sees the winner.
 */
export async function lockDriverAssignment(
  tx: Prisma.TransactionClient,
  driverId: string,
): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${'driver-assign:' + driverId}))`;
}
