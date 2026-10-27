/**
 * Universal / App Links + passkey domain association (DEC-PROD-058). Everything is driven by
 * env so the same build serves dev, staging and prod domains:
 * - APP_LINKS_IOS_APP_IDS: `TEAMID.bundle.id`, comma-separated
 * - APP_LINKS_ANDROID_PACKAGE + APP_LINKS_ANDROID_CERT_SHA256 (colon hex, comma-separated)
 * - APP_LINKS_PATHS: URL paths the app claims (default `/app/*`)
 */
export type AppLinksEnv = {
  APP_LINKS_IOS_APP_IDS?: string;
  APP_LINKS_ANDROID_PACKAGE?: string;
  APP_LINKS_ANDROID_CERT_SHA256?: string;
  APP_LINKS_PATHS?: string;
};

export const DEFAULT_APP_LINK_PATHS = ['/app/*'];

export function splitList(value: string | undefined): string[] {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

const SHA256_FINGERPRINT = /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/;

export function normalizeFingerprints(value: string | undefined): string[] {
  return splitList(value)
    .map((item) => item.toUpperCase())
    .filter((item) => SHA256_FINGERPRINT.test(item));
}

/** Android native passkey origin: `android:apk-key-hash:<base64url(sha256 cert)>`. */
export function androidApkKeyHashOrigin(fingerprint: string): string {
  const bytes = Buffer.from(fingerprint.replace(/:/g, ''), 'hex');
  return `android:apk-key-hash:${bytes.toString('base64url')}`;
}

export function appleAppSiteAssociation(env: AppLinksEnv): Record<string, unknown> | null {
  const appIds = splitList(env.APP_LINKS_IOS_APP_IDS);
  if (appIds.length === 0) {
    return null;
  }
  const paths = splitList(env.APP_LINKS_PATHS);
  return {
    applinks: {
      details: [
        {
          appIDs: appIds,
          components: (paths.length > 0 ? paths : DEFAULT_APP_LINK_PATHS).map((path) => ({ '/': path })),
        },
      ],
    },
    webcredentials: { apps: appIds },
  };
}

export function androidAssetLinks(env: AppLinksEnv): Record<string, unknown>[] | null {
  const packageName = env.APP_LINKS_ANDROID_PACKAGE?.trim();
  const fingerprints = normalizeFingerprints(env.APP_LINKS_ANDROID_CERT_SHA256);
  if (!packageName || fingerprints.length === 0) {
    return null;
  }
  return [
    {
      relation: ['delegate_permission/common.handle_all_urls', 'delegate_permission/common.get_login_creds'],
      target: {
        namespace: 'android_app',
        package_name: packageName,
        sha256_cert_fingerprints: fingerprints,
      },
    },
  ];
}

/**
 * Expected WebAuthn origins: WEBAUTHN_ORIGIN (comma-separated web origins) plus the Android
 * apk-key-hash origin of every configured signing certificate.
 */
export function webauthnExpectedOrigins(origin: string | undefined, env: AppLinksEnv): string[] {
  const origins = splitList(origin);
  for (const fingerprint of normalizeFingerprints(env.APP_LINKS_ANDROID_CERT_SHA256)) {
    origins.push(androidApkKeyHashOrigin(fingerprint));
  }
  return [...new Set(origins)];
}
