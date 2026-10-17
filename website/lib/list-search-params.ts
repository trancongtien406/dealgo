import { parseAsInteger, parseAsString } from "nuqs";
import { DEFAULT_PAGE_SIZE } from "@/lib/admin-pagination";

export const listSearchParams = {
  q: parseAsString.withDefault(""),
  page: parseAsInteger.withDefault(1),
  limit: parseAsInteger.withDefault(DEFAULT_PAGE_SIZE),
};
