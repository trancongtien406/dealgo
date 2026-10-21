import { type INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule, type OpenAPIObject } from '@nestjs/swagger';

export function buildOpenApiDocument(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('DealGo API')
    .setDescription(
      [
        'DealGo REST API for Ride + Food MVP.',
        '',
        'Success responses are wrapped by the Nest response interceptor as:',
        '`{ success: true, statusCode, message, data, requestId }`.',
        'Errors use:',
        '`{ success: false, statusCode, message, errorCode, timestamp, path, requestId }`.',
        '',
        'Money fields are integer VND (no floats). Server is the source of truth for roles,',
        'assignment, status transitions, and committed fares. Do not trust client role/price.',
        '',
        'Ride cancel is allowed while NEGOTIATING or before IN_TRIP',
        '(ASSIGNED / DRIVER_EN_ROUTE / DRIVER_ARRIVED). Food cancel is PLACED only.',
        'COMPLETED / DELIVERED post a sandbox COD ledger journal (balanced, idempotent)',
        'and optionally a PaymentIntent COD row (status SANDBOX_RECORDED).',
        'VNPAY/MoMo create redirect intent (PENDING_REDIRECT) only; webhook stubs may mark CAPTURED_STUB',
        '— not a claim of real settlement.',
        '',
        'MapsPort (ADR-006): MAPS_PROVIDER=mock|goong|google; non-mock without API key is unavailable',
        '(ride reference fare falls back to haversine). Fee formulas bounded by environment configuration.',
        '',
        'KYC/KYB: POST /v1/me/partner-applications; ops review under /v1/ops/partner-applications.',
        'REJECTED sets RoleGrant SUSPENDED; APPROVED sets ACTIVE.',
        'Driver open/ready lists accept optional lat/lng (DRIVER_SEARCH_RADIUS_KM); without coords return a capped list.',
        'Admin PlatformSettings: GET/PATCH /v1/ops/platform-settings',
        '— DB overrides env bootstrap for radius, fare bounds, offer TTL, contact window, payment method flags,',
        'pilot zone label, max concurrent jobs; secrets stay env-only. Ops FAQ CMS: GET/POST/PATCH /v1/ops/faqs',
        '(OPEN-001..021 DRAFT answers labeled PROPOSED; only PUBLISHED for future public/help).',
        'DriverPresence (POST/GET /v1/me/presence): when online=false, open/ready return empty.',
        'FoodStore optional lat/lng (PATCH /v1/food/merchant/store/location); ready radius prefers store coords.',
        'Customer history: GET /v1/rides and GET /v1/food/orders (page/limit, actor-scoped).',
        'Ops CAP-OPS-05: POST /v1/ops/rides|food-orders/:id/cancel {reason} writes OpsAuditLog + outbox;',
        'optional …/reassign allows reassigning (ride→NEGOTIATING pre-trip; food→READY when ASSIGNED).',
        'Ops directory: GET /v1/ops/customers|drivers|stores (page/limit) and GET …/:id — role-scoped users',
        'and FoodStore catalog; no password hashes or refresh tokens.',
        '',
        'Realtime: Socket.IO `subscribe` to `ride:{uuid}` / `food:{uuid}` with Bearer handshake;',
        'outbox relay emits `snapshot` hints and push (mock or FCM HTTP v1 when FCM_* keys set).',
        'Production refuses PUSH_PROVIDER=mock and VOICE_PROVIDER=mock.',
        'Optional Redis Socket.IO adapter when REDIS_URL is up (soft fallback to single-process).',
        'OTP throttling uses Redis storage when REDIS_URL is set; otherwise in-memory.',
        'Ops sandbox settlements: GET `/v1/ops/settlements` groups COD ledger journals by UTC day (no payout).',
        'Ops overview: GET `/v1/ops/overview` — core KPIs + panels hourlyTrend (24h Asia/Ho_Chi_Minh),',
        'recentActivity, ridesByArea, foodByCategory (Ride+Food only; no freight product).',
        'Live board: GET `/v1/ops/monitor/snapshot` — KPIs + mapMarkers, queue, areaDemand, recentActivity,',
        'systemAlerts, optional pilotZoneLabel. Enrichment queries fail-soft (empty arrays; core KPIs preserved).',
        '“today” = Asia/Ho_Chi_Minh calendar day (UTC+7); revenueVnd/commissionVnd are null (no fee invent).',
        'Ops auth methods (DEC-PROD-006 / FR-OPS-010): GET/PATCH `/v1/ops/auth-methods` — PASSKEY,',
        'PHONE_SMS, EMAIL_LOGIN_IDENTIFIER (email is contact/login identifier, not email OTP login).',
        'Defaults ENABLED; refuse disabling the last enabled method; enroll/auth rejects AUTH_METHOD_DISABLED.',
        'OPEN-020 recovery/per-account controls remain open.',
        'Email sign-up is two-step: POST /v1/auth/email/register emails a 6-digit code (no account yet;',
        'same response for existing emails), POST …/register/:id/verify creates the verified account,',
        'grants CUSTOMER and issues a session; …/register/:id/resend has a cooldown. Wrong codes count',
        'per challenge (resend does not reset them); a locked challenge cannot be resent.',
        'Email login with the right password on an unverified email returns 403 AUTH_EMAIL_NOT_VERIFIED',
        'with details {challengeId, expiresAt, resendAvailableAt} and emails an activation code, verified',
        'through the same …/register/:id/verify (marks the email verified, ensures CUSTOMER, issues a session).',
        'Chat + voice (DEC-PROD-007 / 1A): POST/GET messages and POST voice-session on rides/food orders',
        '(participants; audio-only; bounded by CONTACT_WINDOW_MINUTES).',
      ].join('\n'),
    )
    .setVersion('0.1.0')
    .addBearerAuth()
    .addTag('identity', 'Auth, sessions, me, role grants')
    .addTag('rides', 'Ride negotiation and trip lifecycle')
    .addTag('food', 'Food catalog and order lifecycle')
    .addTag('chat', 'Transaction-scoped text chat')
    .addTag('voice', 'In-app audio-only voice sessions (LiveKit/mock)')
    .addTag('payments', 'PSP webhook stubs (VNPAY/MoMo)')
    .addTag('ops', 'Operator explorer (ops session)')
    .addTag('health', 'Liveness / readiness')
    .build();

  return SwaggerModule.createDocument(app, config, {
    operationIdFactory: (_controllerKey: string, methodKey: string) => methodKey,
  });
}

export function shouldServeSwagger(nodeEnv: string, swaggerEnabled: boolean | undefined): boolean {
  if (swaggerEnabled === true) {
    return true;
  }
  if (swaggerEnabled === false) {
    return false;
  }
  return nodeEnv !== 'production';
}
