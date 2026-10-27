import { describe, expect, it } from 'vitest';
import {
  androidApkKeyHashOrigin,
  androidAssetLinks,
  appleAppSiteAssociation,
  webauthnExpectedOrigins,
} from './app-links.js';

const FP = Array.from({ length: 32 }, (_, i) => i.toString(16).padStart(2, '0').toUpperCase()).join(':');

describe('app links', () => {
  it('builds the AASA with applinks + webcredentials only when app IDs are set', () => {
    expect(appleAppSiteAssociation({})).toBeNull();
    const aasa = appleAppSiteAssociation({ APP_LINKS_IOS_APP_IDS: 'TEAM1.com.trancongtien.dealgo' });
    expect(aasa).toEqual({
      applinks: { details: [{ appIDs: ['TEAM1.com.trancongtien.dealgo'], components: [{ '/': '/app/*' }] }] },
      webcredentials: { apps: ['TEAM1.com.trancongtien.dealgo'] },
    });
  });

  it('builds assetlinks with login-credential delegation and drops malformed fingerprints', () => {
    expect(androidAssetLinks({ APP_LINKS_ANDROID_PACKAGE: 'com.x' })).toBeNull();
    const links = androidAssetLinks({
      APP_LINKS_ANDROID_PACKAGE: 'com.trancongtien.dealgo',
      APP_LINKS_ANDROID_CERT_SHA256: `${FP.toLowerCase()}, nope`,
    });
    expect(links?.[0]).toMatchObject({
      relation: expect.arrayContaining(['delegate_permission/common.get_login_creds']),
      target: { package_name: 'com.trancongtien.dealgo', sha256_cert_fingerprints: [FP] },
    });
  });

  it('adds the Android apk-key-hash origin to WebAuthn origins', () => {
    const hash = androidApkKeyHashOrigin(FP);
    expect(hash).toBe(`android:apk-key-hash:${Buffer.from(FP.replace(/:/g, ''), 'hex').toString('base64url')}`);
    expect(webauthnExpectedOrigins('https://dealgo.vn, https://admin.dealgo.vn', { APP_LINKS_ANDROID_CERT_SHA256: FP })).toEqual([
      'https://dealgo.vn',
      'https://admin.dealgo.vn',
      hash,
    ]);
  });
});
