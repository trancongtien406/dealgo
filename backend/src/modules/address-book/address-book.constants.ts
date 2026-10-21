export const ADDRESS_BOOK_REPOSITORY = Symbol('ADDRESS_BOOK_REPOSITORY');

/** Saved addresses per user. */
export const ADDRESS_BOOK_LIMIT = 20;

export const SAVED_ADDRESS_KINDS = ['HOME', 'WORK', 'OTHER'] as const;
export type SavedAddressKind = (typeof SAVED_ADDRESS_KINDS)[number];
