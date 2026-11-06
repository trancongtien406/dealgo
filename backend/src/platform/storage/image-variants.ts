import sharp from 'sharp';

/**
 * Display widths generated for every public image. A phone asks for the smallest variant
 * that covers its physical pixel width, so a 72 px avatar never downloads the 1080 px cover.
 */
export const PUBLIC_IMAGE_VARIANT_WIDTHS = [128, 240, 480, 1080] as const;

const MAX_VARIANT_WIDTH = PUBLIC_IMAGE_VARIANT_WIDTHS.at(-1)!;
const WEBP_QUALITY = 78;
const VARIANT_WEBP_QUALITY = 72;
const WEBP_EFFORT = 3;
/** Refuse to decode absurdly large uploads instead of blocking the event loop on them. */
const MAX_INPUT_PIXELS = 40_000_000;

export type NormalizedImage = {
  body: Buffer;
  width: number;
  height: number;
};

/** Pixel size of an existing object, without re-encoding it. */
export async function readImageSize(
  input: Buffer,
): Promise<{ width: number; height: number } | null> {
  try {
    const meta = await sharp(input, {
      failOn: 'none',
      limitInputPixels: MAX_INPUT_PIXELS,
    }).metadata();
    return meta.width && meta.height
      ? { width: meta.width, height: meta.height }
      : null;
  } catch {
    return null;
  }
}

/** Rewrites PNG/JPEG uploads to WebP and returns the pixel width so callers can size variants. */
export async function toPublicWebp(input: Buffer): Promise<NormalizedImage | null> {
  try {
    const { data, info } = await sharp(input, {
      failOn: 'none',
      limitInputPixels: MAX_INPUT_PIXELS,
    })
      .rotate()
      .webp({ quality: WEBP_QUALITY, effort: WEBP_EFFORT })
      .toBuffer({ resolveWithObject: true });
    return { body: data, width: info.width, height: info.height };
  } catch {
    return null;
  }
}

export async function toVariantWebp(input: Buffer, width: number): Promise<Buffer | null> {
  try {
    return await sharp(input, {
      failOn: 'none',
      limitInputPixels: MAX_INPUT_PIXELS,
    })
      .resize({ width, withoutEnlargement: true, fit: 'inside' })
      .webp({ quality: VARIANT_WEBP_QUALITY, effort: WEBP_EFFORT })
      .toBuffer();
  } catch {
    return null;
  }
}

/** `store-covers/<id>/<uuid>.webp` at 480 px → `store-covers/<id>/<uuid>.w480.webp`. */
export function imageVariantKey(storageKey: string, width: number): string | null {
  const match = /\.(?:webp|png|jpe?g)$/i.exec(storageKey);
  if (!match) {
    return null;
  }
  return `${storageKey.slice(0, match.index)}.w${width}.webp`;
}

/**
 * Maps a client's physical pixel width (`w`, already multiplied by devicePixelRatio) to the
 * smallest generated variant that still looks sharp. Omitted or invalid values keep the
 * original object, so old clients and full-size views stay unaffected.
 */
export function resolveImageVariantWidth(raw: unknown): number | null {
  if (raw === undefined || raw === null || raw === '') {
    return null;
  }
  const value = Number(Array.isArray(raw) ? raw[0] : raw);
  if (!Number.isFinite(value) || value <= 0) {
    return null;
  }
  const target = Math.min(value, MAX_VARIANT_WIDTH);
  return PUBLIC_IMAGE_VARIANT_WIDTHS.find((width) => width >= target) ?? MAX_VARIANT_WIDTH;
}
