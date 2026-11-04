/** Query params that carry a customer's free-text keyword; their values must never be logged. */
const KEYWORD_PARAMS = new Set(['q', 'search']);
const REDACTED = '[redacted]';

/** The path of a request URL, with the query string dropped. */
export function pathWithoutQuery(url: string): string {
  const queryStart = url.indexOf('?');
  return queryStart < 0 ? url : url.slice(0, queryStart);
}

/**
 * The request URL with keyword param values masked. Path and every other param are
 * left byte-identical so access logs and error reports stay useful.
 */
export function redactUrl(url: string): string {
  const queryStart = url.indexOf('?');
  if (queryStart < 0) {
    return url;
  }
  const query = url.slice(queryStart + 1);
  if (query === '') {
    return url;
  }
  const redacted = query
    .split('&')
    .map((pair) => {
      const separator = pair.indexOf('=');
      const rawName = separator < 0 ? pair : pair.slice(0, separator);
      if (!KEYWORD_PARAMS.has(decodeName(rawName))) {
        return pair;
      }
      return `${rawName}=${REDACTED}`;
    })
    .join('&');
  return `${url.slice(0, queryStart)}?${redacted}`;
}

function decodeName(rawName: string): string {
  try {
    return decodeURIComponent(rawName).toLowerCase();
  } catch {
    return rawName.toLowerCase();
  }
}
