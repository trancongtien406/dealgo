import { MemoryObjectStorage } from '../../integrations/object-storage/memory-object-storage.js';
import type { PlatformSettingsService } from '../settings/platform-settings.service.js';
import { DocumentStoreService } from './document-store.service.js';

/** Smallest byte strings that pass the upload signature checks (tests only). */
export const TINY_JPEG_BASE64 = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46]).toString(
  'base64',
);
/** t54u: smallest `ftyp` box the upload sniffer accepts as video/mp4. */
export const TINY_MP4_BASE64 = Buffer.concat([
  Buffer.from([0, 0, 0, 0x18]),
  Buffer.from('ftypisom', 'latin1'),
  Buffer.alloc(16, 1),
]).toString('base64');
export const TINY_PNG_BASE64 = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d,
]).toString('base64');
export const TINY_PDF_BASE64 = Buffer.from('%PDF-1.4\n%test\n', 'latin1').toString('base64');

export function createTestDocumentStore(
  limits: { maxFileKb?: number; allowedTypes?: string[] } = {},
): { store: DocumentStoreService; storage: MemoryObjectStorage } {
  const storage = new MemoryObjectStorage();
  const settings = {
    getNumber: async (key: string) => (key === 'UPLOAD_MAX_FILE_KB' ? (limits.maxFileKb ?? 4096) : 0),
    getJson: async () => limits.allowedTypes ?? ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
  } as unknown as PlatformSettingsService;
  return { store: new DocumentStoreService(storage, settings), storage };
}
