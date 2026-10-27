import { foldVietnamese, type GeoPoint, type PlaceSuggestion } from '../../integrations/maps/maps-port.js';
import { haversineKm } from '../../shared/geo/haversine.js';

export type ParsedPlaceQuery = {
  /** Text as typed (trimmed). */
  raw: string;
  /** House number typed before the street ("12", "12A", "45/7"), if any. */
  houseNumber: string | null;
  /** Query without the house number: what the providers are asked for. */
  street: string;
  /** Folded street text used for matching. */
  folded: string;
};

const HOUSE_NUMBER = /^(?:s[oố]\s+)?(\d{1,5}[a-z]?(?:\/\d{1,5}[a-z]?){0,3})\s+(.{2,})$/iu;
/** Leading words that name the kind of way, not the street itself. */
const STREET_PREFIX = /^(duong|pho|tuyen duong|dai lo)\s+/;
/** Alleys ("Kiệt 376 Nguyễn Hoàng", "Hẻm 65 …") rank below the street itself. */
const ALLEY_PREFIX = /^(kiet|hem|ngo|ngach)\s/;

/** Splits "12 Nguyễn Hoàng" into the house number and the street part. */
export function parsePlaceQuery(input: string): ParsedPlaceQuery {
  const raw = input.trim().replace(/\s+/g, ' ');
  const match = HOUSE_NUMBER.exec(raw);
  const street = match ? match[2]!.trim() : raw;
  return {
    raw,
    houseNumber: match ? match[1]!.toUpperCase() : null,
    street,
    folded: foldVietnamese(street),
  };
}

function stripPrefix(folded: string): string {
  return folded.replace(STREET_PREFIX, '');
}

/**
 * 3 exact name ("Đường Nguyễn Hoàng" = "nguyen hoang"), 2 name starts with the
 * query, 1.5 every word in the name, 1 every word in name + address, 0 otherwise.
 */
export function textScore(place: PlaceSuggestion, query: ParsedPlaceQuery): number {
  const q = stripPrefix(query.folded.split(',')[0]!.trim());
  if (!q) return 0;
  const name = stripPrefix(foldVietnamese(place.name).replace(/^\d+[a-z]?(\/\d+[a-z]?)*\s+/, ''));
  if (ALLEY_PREFIX.test(name) && !ALLEY_PREFIX.test(q)) {
    return foldVietnamese(query.street).split(/[\s,]+/).filter(Boolean).every((w) => name.includes(w)) ? 1.2 : 0;
  }
  if (name === q) return 3;
  if (name.startsWith(`${q} `) || name.startsWith(q)) return 2;
  const words = foldVietnamese(query.street).split(/[\s,]+/).filter(Boolean);
  const nameWords = new Set(name.split(' '));
  if (words.every((w) => nameWords.has(w) || name.includes(w))) return 1.5;
  const all = `${name} ${foldVietnamese(place.address)}`;
  return words.every((w) => all.includes(w)) ? 1 : 0;
}

/**
 * Grab/Be-style tiers: the current city first, then nearby provinces, then the
 * rest of the country.
 */
export function distanceTier(km: number | null): number {
  if (km == null) return 0;
  if (km <= 20) return 3;
  if (km <= 80) return 2;
  if (km <= 300) return 1;
  return 0;
}

export type RankedPlace = PlaceSuggestion & { distanceKm?: number };

/**
 * Merges provider candidates: drops text misses (when anything matches),
 * de-duplicates the same name within ~150 m, and sorts by distance tier, then
 * text match, then distance. A typed house number the providers do not know is
 * put on the matching street, flagged approximate.
 */
export function rankPlaces(
  candidates: readonly PlaceSuggestion[],
  query: ParsedPlaceQuery,
  near: GeoPoint | undefined,
  limit: number,
): RankedPlace[] {
  const scored = candidates.map((place, index) => {
    const km = near ? haversineKm(near, place) : null;
    return { place, km, text: textScore(place, query), tier: distanceTier(km), index };
  });
  const matching = scored.filter((s) => s.text > 0);
  const pool = matching.length > 0 ? matching : scored;
  pool.sort(
    (a, b) =>
      b.tier - a.tier ||
      b.text - a.text ||
      (a.km ?? 0) - (b.km ?? 0) ||
      a.index - b.index,
  );
  const out: RankedPlace[] = [];
  for (const entry of pool) {
    const place = tidy(withHouseNumber(entry.place, query, entry.text));
    const folded = stripPrefix(foldVietnamese(place.name));
    const area = areaOf(place);
    // One row per street per ward: OSM splits a street into many segments.
    const dup = out.some((kept) => {
      if (stripPrefix(foldVietnamese(kept.name)) !== folded) return false;
      const km = haversineKm(kept, place);
      return km < 0.5 || (km < 2.5 && areaOf(kept) === area);
    });
    if (dup) continue;
    out.push(entry.km == null ? place : { ...place, distanceKm: Math.round(entry.km * 10) / 10 });
    if (out.length >= limit) break;
  }
  return out;
}

/** First locality after the name ("Hòa Cường"), folded. */
function areaOf(place: PlaceSuggestion): string {
  return foldVietnamese(place.address.split(',')[1] ?? '').trim();
}

/** Drops postcodes and the trailing country from provider labels. */
export function tidyAddress(address: string): string {
  return address
    .split(',')
    .map((part) => part.trim())
    .filter((part) => part && !/^\d{5,6}$/.test(part) && !/^(việt nam|vietnam|viet nam)$/i.test(part))
    .join(', ');
}

function tidy(place: PlaceSuggestion): PlaceSuggestion {
  const address = tidyAddress(place.address);
  return address === place.address ? place : { ...place, address };
}

function withHouseNumber(
  place: PlaceSuggestion,
  query: ParsedPlaceQuery,
  text: number,
): PlaceSuggestion {
  const number = query.houseNumber;
  if (!number || text < 2) return place;
  const folded = foldVietnamese(place.name);
  if (folded.startsWith(`${number.toLowerCase()} `)) return place;
  if (place.kind !== 'street') return place;
  const street = place.name.replace(/^(Đường|Phố)\s+/u, '');
  const name = `${number} ${street}`;
  const rest = place.address.split(',').slice(1).join(',').trim();
  return {
    ...place,
    name,
    address: rest ? `${name}, ${rest}` : name,
    approximate: true,
  };
}

/** ~50 km box around [near] for the city-first pass. */
export function localBbox(near: GeoPoint, degrees = 0.45): [number, number, number, number] {
  return [near.lng - degrees, near.lat - degrees, near.lng + degrees, near.lat + degrees];
}
