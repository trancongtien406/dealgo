import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { resolveFcmCredentials } from './fcm-credentials.js';

describe('resolveFcmCredentials', () => {
  it('prefers explicit FCM_* fields over a service-account path', () => {
    const credentials = resolveFcmCredentials({
      projectId: 'from-env',
      clientEmail: 'env@example.com',
      privateKey:
        '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n',
      serviceAccountPath: '/does/not/exist.json',
    });

    expect(credentials).toEqual({
      projectId: 'from-env',
      clientEmail: 'env@example.com',
      privateKey:
        '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n',
    });
  });

  it('loads project_id, client_email, and private_key from a service-account JSON', () => {
    const dir = mkdtempSync(join(tmpdir(), 'dealgo-fcm-'));
    const path = join(dir, 'sa.json');
    writeFileSync(
      path,
      JSON.stringify({
        type: 'service_account',
        project_id: 'dealgo-test',
        client_email: 'firebase-adminsdk@dealgo-test.iam.gserviceaccount.com',
        private_key:
          '-----BEGIN PRIVATE KEY-----\nxyz\n-----END PRIVATE KEY-----\n',
      }),
    );

    const credentials = resolveFcmCredentials({ serviceAccountPath: path });

    expect(credentials).toEqual({
      projectId: 'dealgo-test',
      clientEmail: 'firebase-adminsdk@dealgo-test.iam.gserviceaccount.com',
      privateKey:
        '-----BEGIN PRIVATE KEY-----\nxyz\n-----END PRIVATE KEY-----\n',
    });
  });

  it('returns null when neither FCM_* nor a readable path is available', () => {
    expect(resolveFcmCredentials({})).toBeNull();
    expect(
      resolveFcmCredentials({
        serviceAccountPath: '/tmp/dealgo-missing-sa.json',
      }),
    ).toBeNull();
  });
});
