import { S3KycStorage } from './s3-kyc-storage.js';

describe('S3KycStorage', () => {
  it('returns null when S3 config is incomplete (fail-closed)', () => {
    expect(
      S3KycStorage.tryFromEnv({
        S3_ENDPOINT: 'https://s3.example.com',
        S3_REGION: 'auto',
        S3_BUCKET: 'dealgo',
        S3_ACCESS_KEY_ID: 'key',
      }),
    ).toBeNull();
  });

  it('constructs when all required fields are set', () => {
    const storage = S3KycStorage.tryFromEnv({
      S3_ENDPOINT: 'https://s3.example.com',
      S3_REGION: 'auto',
      S3_BUCKET: 'dealgo',
      S3_ACCESS_KEY_ID: 'key',
      S3_SECRET_ACCESS_KEY: 'secret',
    });
    expect(storage).toBeInstanceOf(S3KycStorage);
  });

  it('builds a SigV4 presigned GET URL', () => {
    const storage = new S3KycStorage({
      endpoint: 'https://s3.example.com',
      region: 'us-east-1',
      bucket: 'dealgo',
      accessKeyId: 'AKIAEXAMPLE',
      secretAccessKey: 'secret',
    });
    const url = storage.createPresignedGetUrl('partner-applications/app-1/0-id.jpg');
    expect(url).toContain('https://s3.example.com/dealgo/partner-applications/');
    expect(url).toContain('X-Amz-Algorithm=AWS4-HMAC-SHA256');
    expect(url).toContain('X-Amz-Signature=');
  });
});
