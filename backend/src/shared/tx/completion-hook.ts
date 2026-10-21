/**
 * Work that must commit or roll back together with a job's state change (ride completion,
 * food delivery). In Prisma mode `tx` is the open `Prisma.TransactionClient`; in memory mode
 * it is `null` and repositories write straight to their in-memory stores.
 */
export type TxHandle = unknown;

export type CompletionHook<T> = (tx: TxHandle, job: T) => Promise<void>;
