export type StoredDocumentRef = {
  key: string;
  label: string;
  contentType: string;
  sizeBytes: number;
  uploadedAt: string;
};

export type KycStorage = {
  storeDocuments(
    applicationId: string,
    files: Array<{ label: string; contentType?: string; contentBase64?: string }>,
  ): Promise<StoredDocumentRef[]>;
};

/**
 * Mock KYC/KYB storage: persists only object keys + lightweight metadata in jsonb.
 * Production must use a real object store; NODE_ENV=production rejects mock provider.
 */
export class MockKycStorage implements KycStorage {
  async storeDocuments(
    applicationId: string,
    files: Array<{ label: string; contentType?: string; contentBase64?: string }>,
  ): Promise<StoredDocumentRef[]> {
    const uploadedAt = new Date().toISOString();
    return files.map((file, index) => {
      const safeLabel = file.label.replace(/[^a-zA-Z0-9._-]+/g, '_').slice(0, 80) || `doc-${index}`;
      const sizeBytes =
        typeof file.contentBase64 === 'string'
          ? Math.floor((file.contentBase64.length * 3) / 4)
          : 0;
      return {
        key: `mock://partner-applications/${applicationId}/${index}-${safeLabel}`,
        label: file.label.slice(0, 160),
        contentType: file.contentType?.slice(0, 120) || 'application/octet-stream',
        sizeBytes,
        uploadedAt,
      };
    });
  }
}

export class UnavailableKycStorage implements KycStorage {
  async storeDocuments(): Promise<StoredDocumentRef[]> {
    throw new Error('KYC storage provider is not configured');
  }
}
