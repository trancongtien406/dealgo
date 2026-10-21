import { Inject, Injectable, Logger } from '@nestjs/common';
import type { ObjectStorage } from '../integrations/object-storage/object-storage.port.js';
import { PlatformSettingsService } from '../platform/settings/platform-settings.service.js';
import { OBJECT_STORAGE } from '../platform/storage/storage.constants.js';
import {
  UPLOAD_PREFIXES,
  UPLOAD_REFERENCE_SOURCE,
  type UploadReferenceSource,
} from './upload-references.js';

/** Never delete anything younger than this, whatever the setting says (mid-request uploads). */
export const ORPHAN_MIN_AGE_HOURS = 24;
/** Deletions per run; the rest waits for the next run so one pass never hammers storage. */
export const ORPHAN_MAX_DELETES_PER_RUN = 500;

export type OrphanCleanupReport =
  | { ran: false; reason: 'storage-unavailable' | 'no-database' | 'already-running' }
  | {
      ran: true;
      maxAgeHours: number;
      scanned: number;
      referenced: number;
      tooYoung: number;
      deleted: number;
      failed: number;
      capped: boolean;
    };

/**
 * DEC-PROD-022: removes stored uploads that no record points to (a crash between the file write
 * and the database write, a failed best-effort discard, a replaced document). Runs on the worker;
 * the age threshold is the admin setting UPLOAD_ORPHAN_MAX_AGE_HOURS.
 */
@Injectable()
export class OrphanUploadCleanupService {
  private readonly logger = new Logger(OrphanUploadCleanupService.name);
  private running = false;

  constructor(
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(UPLOAD_REFERENCE_SOURCE) private readonly references: UploadReferenceSource,
    private readonly settings: PlatformSettingsService,
  ) {}

  async runOnce(now: Date = new Date()): Promise<OrphanCleanupReport> {
    if ((this.storage as { unavailable?: boolean }).unavailable) {
      return { ran: false, reason: 'storage-unavailable' };
    }
    if (this.running) {
      return { ran: false, reason: 'already-running' };
    }
    this.running = true;
    try {
      // References are read before listing: a file saved after this snapshot is younger than
      // the age floor, so it can never be mistaken for an orphan.
      const referenced = await this.references.referencedKeys();
      if (!referenced) {
        return { ran: false, reason: 'no-database' };
      }
      const setting = await this.settings.getNumber('UPLOAD_ORPHAN_MAX_AGE_HOURS');
      const maxAgeHours = Math.max(ORPHAN_MIN_AGE_HOURS, Number.isFinite(setting) ? setting : 72);
      const cutoff = now.getTime() - maxAgeHours * 3_600_000;
      const report = {
        ran: true as const,
        maxAgeHours,
        scanned: 0,
        referenced: 0,
        tooYoung: 0,
        deleted: 0,
        failed: 0,
        capped: false,
      };
      outer: for (const prefix of UPLOAD_PREFIXES) {
        for await (const item of this.storage.list(prefix)) {
          report.scanned += 1;
          if (referenced.has(item.key)) {
            report.referenced += 1;
            continue;
          }
          if (item.lastModified.getTime() > cutoff) {
            report.tooYoung += 1;
            continue;
          }
          if (report.deleted + report.failed >= ORPHAN_MAX_DELETES_PER_RUN) {
            report.capped = true;
            break outer;
          }
          try {
            await this.storage.delete(item.key);
            report.deleted += 1;
          } catch (error) {
            report.failed += 1;
            this.logger.warn(`Could not delete orphan ${item.key}: ${(error as Error).message}`);
          }
        }
      }
      this.logger.log({ msg: 'uploads.orphan_cleanup', ...report });
      return report;
    } finally {
      this.running = false;
    }
  }
}
