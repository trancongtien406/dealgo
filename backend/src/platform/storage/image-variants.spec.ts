import sharp from 'sharp';
import { describe, expect, it, vi } from 'vitest';
import {
  imageVariantKey,
  resolveImageVariantWidth,
} from './image-variants.js';
import { createTestDocumentStore, TINY_PNG_BASE64 } from './testing.js';

async function png(width: number, height: number): Promise<Buffer> {
  return sharp({
    create: { width, height, channels: 3, background: { r: 120, g: 140, b: 160 } },
  })
    .png()
    .toBuffer();
}

describe('resolveImageVariantWidth', () => {
  it('snaps a physical pixel width up to the smallest covering variant', () => {
    expect(resolveImageVariantWidth('100')).toBe(128);
    expect(resolveImageVariantWidth('129')).toBe(240);
    expect(resolveImageVariantWidth('400')).toBe(480);
    expect(resolveImageVariantWidth('900')).toBe(1080);
  });

  it('keeps the largest variant for very wide requests', () => {
    expect(resolveImageVariantWidth('3000')).toBe(1080);
  });

  it('ignores missing or invalid values so the original is served', () => {
    expect(resolveImageVariantWidth(undefined)).toBeNull();
    expect(resolveImageVariantWidth('')).toBeNull();
    expect(resolveImageVariantWidth('abc')).toBeNull();
    expect(resolveImageVariantWidth('0')).toBeNull();
    expect(resolveImageVariantWidth('-10')).toBeNull();
  });
});

describe('imageVariantKey', () => {
  it('inserts the width before the extension', () => {
    expect(imageVariantKey('menu-items/i/photo.webp', 480)).toBe(
      'menu-items/i/photo.w480.webp',
    );
    expect(imageVariantKey('avatars/u/photo.png', 128)).toBe('avatars/u/photo.w128.webp');
  });

  it('has no variant for documents and videos', () => {
    expect(imageVariantKey('support-attachments/t/receipt.pdf', 480)).toBeNull();
    expect(imageVariantKey('partner-applications/a/clip.mp4', 480)).toBeNull();
  });
});

describe('DocumentStoreService public images', () => {
  it('stores webp plus one variant per display width and serves the requested one', async () => {
    const { store } = createTestDocumentStore();
    const source = await png(800, 400);
    const refs = await store.storePublicThen(
      'store-covers/s1',
      [{ label: 'cover', contentType: 'image/png', contentBase64: source.toString('base64') }],
      async (stored) => stored,
    );
    const ref = refs[0]!;
    expect(ref.key).toMatch(/^store-covers\/s1\/[0-9a-f-]{36}\.webp$/);
    expect(ref.contentType).toBe('image/webp');

    for (const width of [128, 240, 480]) {
      expect(await store.read(ref, width)).not.toBeNull();
    }
    const original = await store.read(ref);
    const small = await store.read(ref, 240);
    expect(small?.contentType).toBe('image/webp');
    expect(small!.body.byteLength).toBeLessThan(original!.body.byteLength);

    await store.discard([ref]);
    expect(await store.read(ref)).toBeNull();
    expect(await store.read(ref, 240)).toBeNull();
  });

  it('falls back to the original when the width variant was never generated', async () => {
    const { store } = createTestDocumentStore();
    const source = await png(300, 300);
    const [ref] = await store.storePublicThen(
      'avatars/u1',
      [{ label: 'avatar', contentType: 'image/png', contentBase64: source.toString('base64') }],
      async (stored) => stored,
    );
    const wide = await store.read(ref!, 1080);
    expect(wide).not.toBeNull();
    expect(wide?.contentType).toBe('image/webp');
  });

  it('serves repeat views from memory instead of object storage', async () => {
    const { store, storage } = createTestDocumentStore();
    const source = await png(900, 450);
    const [ref] = await store.storePublicThen(
      'store-covers/s9',
      [{ label: 'cover', contentType: 'image/png', contentBase64: source.toString('base64') }],
      async (stored) => stored,
    );
    const get = vi.spyOn(storage, 'get');
    expect(await store.readDisplayImage(ref!, 480)).not.toBeNull();
    expect(await store.readDisplayImage(ref!, 480)).not.toBeNull();
    expect(get).toHaveBeenCalledTimes(1);

    await store.discard([ref!]);
    get.mockClear();
    expect(await store.readDisplayImage(ref!, 480)).toBeNull();
  });

  it('keeps an image the re-encoder cannot read', async () => {
    const { store } = createTestDocumentStore();
    const [ref] = await store.storePublicThen(
      'avatars/u2',
      [{ label: 'avatar', contentType: 'image/png', contentBase64: TINY_PNG_BASE64 }],
      async (stored) => stored,
    );
    expect(ref!.key).toMatch(/\.png$/);
    expect(ref!.contentType).toBe('image/png');
    const read = await store.read(ref!, 240);
    expect(read?.contentType).toBe('image/png');
  });
});
