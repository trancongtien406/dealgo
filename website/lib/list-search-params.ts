import { parseAsInteger, parseAsString } from "nuqs";
import { DEFAULT_PAGE_SIZE } from "@/lib/admin-pagination";

export const listSearchParams = {
  q: parseAsString.withDefault(""),
  page: parseAsInteger.withDefault(1),
  limit: parseAsInteger.withDefault(DEFAULT_PAGE_SIZE),
};

/** `from` / `to` (YYYY-MM-DD, inclusive Vietnam days) for lists with a server date filter. */
export const dateRangeSearchParams = {
  from: parseAsString.withDefault(""),
  to: parseAsString.withDefault(""),
};
