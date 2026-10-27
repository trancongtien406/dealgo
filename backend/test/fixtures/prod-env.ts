/**
 * A complete, valid NODE_ENV=production env with dummy values (DEC-PROD-050). Specs spread it and
 * override single keys so the strict production provider checks pass. Never real secrets.
 */
export const PROD_ENV_OK: Record<string, string | undefined> = {
  NODE_ENV: 'production',
  JWT_ACCESS_SECRET: 'production-secret',
  CHAT_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString('base64'),
  SMS_PROVIDER: 'esms',
  ESMS_API_KEY: 'k',
  ESMS_SECRET_KEY: 's',
  ESMS_BRANDNAME: 'DealGo',
  EMAIL_PROVIDER: 'ses',
  SES_REGION: 'ap-southeast-1',
  SES_ACCESS_KEY_ID: 'AKIA',
  SES_SECRET_ACCESS_KEY: 'secret',
  EMAIL_FROM: 'DealGo <noreply@dealgo.vn>',
  PUSH_PROVIDER: 'fcm',
  FCM_PROJECT_ID: 'dealgo',
  FCM_CLIENT_EMAIL: 'svc@dealgo.iam.gserviceaccount.com',
  FCM_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\\nMIIB\\n-----END PRIVATE KEY-----\\n',
  MAPS_PROVIDER: 'mapbox',
  MAPBOX_ACCESS_TOKEN: 'pk.test',
  ROUTING_PROVIDER: 'mapbox',
  MAPBOX_DIRECTIONS_TOKEN: 'pk.test',
  PAYMENT_PROVIDER: 'cash-only',
  WEBAUTHN_RP_ID: 'dealgo.vn',
  WEBAUTHN_RP_NAME: 'DealGo',
  WEBAUTHN_ORIGIN: 'https://dealgo.vn',

};
