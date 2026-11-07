import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { IdentityModule } from '../../../src/modules/identity/identity.module.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';

const ROOT = { email: 'root@dealgo.test', password: 'root-password-123' };
const STAFF = { email: 'staff@dealgo.test', password: 'staff-password-123' };
const OTHER = { email: 'other@dealgo.test', password: 'other-password-123' };

describe('ops staff password reset (DEC-PROD-036)', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;

  const login = (who: { email: string; password: string }) =>
    request(app.getHttpServer()).post('/v1/ops/sessions').send(who);

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              JWT_ACCESS_SECRET: 'test-access-secret',
              JWT_ACCESS_TTL_SECONDS: '900',
              SMS_PROVIDER: 'mock',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        IdentityModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(new MockSmsSender('test'))
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    const ops = app.get(OpsAuthService);
    await ops.ensureOperator(ROOT.email, ROOT.password, 'test', { superAdmin: true });
    await ops.ensureOperator(STAFF.email, STAFF.password, 'test');
    await ops.ensureOperator(OTHER.email, OTHER.password, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  it('lets only a super-admin reset another operator, revoking their sessions', async () => {
    const root = (await login(ROOT).expect(200)).body.data;
    const staff = (await login(STAFF).expect(200)).body.data;
    const other = (await login(OTHER).expect(200)).body.data;
    const staffId = staff.user.id as string;
    const otherId = other.user.id as string;
    const rootToken = root.accessToken as string;

    const me = await request(app.getHttpServer())
      .get('/v1/ops/staff/me')
      .set('Authorization', `Bearer ${rootToken}`)
      .expect(200);
    expect(me.body.data).toEqual(
      expect.objectContaining({ id: root.user.id, superAdmin: true, staffRole: 'ADMIN' }),
    );
    expect(me.body.data.permissions).toEqual(expect.any(Array));
    expect(me.body.data.permissions.length).toBeGreaterThan(0);
    const staffMe = await request(app.getHttpServer())
      .get('/v1/ops/staff/me')
      .set('Authorization', `Bearer ${staff.accessToken}`)
      .expect(200);
    expect(staffMe.body.data.superAdmin).toBe(false);

    // A plain operator cannot reset anyone.
    const denied = await request(app.getHttpServer())
      .post(`/v1/ops/staff/${otherId}/password-reset`)
      .set('Authorization', `Bearer ${staff.accessToken}`)
      .send({ newPassword: 'brand-new-password-1', reason: 'forgot it' })
      .expect(403);
    expect(denied.body.errorCode).toBe('OPS_SUPER_ADMIN_REQUIRED');

    // Not on yourself, and the password must be long enough.
    const self = await request(app.getHttpServer())
      .post(`/v1/ops/staff/${root.user.id}/password-reset`)
      .set('Authorization', `Bearer ${rootToken}`)
      .send({ newPassword: 'brand-new-password-1', reason: 'self' })
      .expect(400);
    expect(self.body.errorCode).toBe('OPS_RESET_SELF');
    await request(app.getHttpServer())
      .post(`/v1/ops/staff/${staffId}/password-reset`)
      .set('Authorization', `Bearer ${rootToken}`)
      .send({ newPassword: 'short', reason: 'forgot it' })
      .expect(400);

    const reset = await request(app.getHttpServer())
      .post(`/v1/ops/staff/${staffId}/password-reset`)
      .set('Authorization', `Bearer ${rootToken}`)
      .send({ newPassword: 'brand-new-password-1', reason: 'Forgot password, verified by phone' })
      .expect(200);
    expect(reset.body.data).toEqual({ userId: staffId, sessionsRevoked: true });

    // Forced re-login: the old session is dead, the old password no longer works.
    await request(app.getHttpServer())
      .get('/v1/ops/staff/me')
      .set('Authorization', `Bearer ${staff.accessToken}`)
      .expect(401);
    await login(STAFF).expect(401);
    await login({ email: STAFF.email, password: 'brand-new-password-1' }).expect(200);
    // Other operators keep their sessions.
    await request(app.getHttpServer())
      .get('/v1/ops/staff/me')
      .set('Authorization', `Bearer ${other.accessToken}`)
      .expect(200);

    expect(identity.opsAudits).toEqual([
      {
        actorUserId: root.user.id,
        action: 'OPS_PASSWORD_RESET',
        entityId: staffId,
        reason: 'Forgot password, verified by phone',
      },
    ]);
  });

  it('refuses unknown staff and users without an Admin password', async () => {
    const root = (await login(ROOT).expect(200)).body.data;
    const missing = await request(app.getHttpServer())
      .post('/v1/ops/staff/6f1c2c4e-0000-4000-8000-000000000999/password-reset')
      .set('Authorization', `Bearer ${root.accessToken}`)
      .send({ newPassword: 'brand-new-password-1', reason: 'unknown' })
      .expect(404);
    expect(missing.body.errorCode).toBe('OPS_STAFF_NOT_FOUND');

    const user = await identity.createUser({ email: 'noslogin@dealgo.test', phone: null, displayName: 'No login' });
    await identity.insertGrant(user.id, 'OPS', 'ACTIVE');
    const noLogin = await request(app.getHttpServer())
      .post(`/v1/ops/staff/${user.id}/password-reset`)
      .set('Authorization', `Bearer ${root.accessToken}`)
      .send({ newPassword: 'brand-new-password-1', reason: 'no login' })
      .expect(409);
    expect(noLogin.body.errorCode).toBe('OPS_NO_PASSWORD_LOGIN');
  });

  it('lets a super-admin grant super-admin but revoking is forbidden', async () => {
    const root = (await login(ROOT).expect(200)).body.data;
    const other = (await login(OTHER).expect(200)).body.data;
    const flag = (token: string, id: string, superAdmin: boolean, reason = 'Phân quyền quản trị') =>
      request(app.getHttpServer())
        .post(`/v1/ops/staff/${id}/super-admin`)
        .set('Authorization', `Bearer ${token}`)
        .send({ superAdmin, reason });
    const before = identity.opsAudits.length;

    const denied = await flag(other.accessToken, root.user.id, true).expect(403);
    expect(denied.body.errorCode).toBe('OPS_SUPER_ADMIN_REQUIRED');
    await flag(root.accessToken, other.user.id, true, 'x').expect(400);

    // Super-admin cannot be revoked.
    const revokeAttempt = await flag(root.accessToken, root.user.id, false).expect(400);
    expect(revokeAttempt.body.errorCode).toBe('OPS_SUPER_ADMIN_REVOKE_FORBIDDEN');

    const granted = await flag(root.accessToken, other.user.id, true).expect(200);
    expect(granted.body.data).toEqual({ userId: other.user.id, superAdmin: true });
    // Idempotent: granting again changes and audits nothing.
    await flag(root.accessToken, other.user.id, true).expect(200);
    const otherMe = await request(app.getHttpServer())
      .get('/v1/ops/staff/me')
      .set('Authorization', `Bearer ${other.accessToken}`)
      .expect(200);
    expect(otherMe.body.data.superAdmin).toBe(true);

    // Revoking other is also forbidden.
    const revokeOther = await flag(root.accessToken, other.user.id, false).expect(400);
    expect(revokeOther.body.errorCode).toBe('OPS_SUPER_ADMIN_REVOKE_FORBIDDEN');

    expect(identity.opsAudits.slice(before).map((a) => [a.action, a.entityId])).toEqual([
      ['OPS_SUPER_ADMIN_GRANT', other.user.id],
    ]);

    const missing = await flag(root.accessToken, '6f1c2c4e-0000-4000-8000-000000000999', true).expect(404);
    expect(missing.body.errorCode).toBe('OPS_STAFF_NOT_FOUND');
  });

  it('enforces the staff role matrix on ops routes; super-admin bypasses (DEC-PROD-044)', async () => {
    const root = (await login(ROOT).expect(200)).body.data;
    // STAFF is a plain operator (OTHER became super-admin above); password set in the first test.
    const other = (await login({ email: STAFF.email, password: 'brand-new-password-1' }).expect(200)).body.data;
    const missing = '00000000-0000-4000-8000-000000000001';

    await request(app.getHttpServer())
      .post(`/v1/ops/staff/${other.user.id}/staff-role`)
      .set('Authorization', `Bearer ${root.accessToken}`)
      .send({ staffRole: 'SUPPORT', reason: 'CSKH ca tối' })
      .expect(200);
    expect(identity.opsAudits.at(-1)).toEqual(
      expect.objectContaining({ action: 'OPS_STAFF_ROLE_ASSIGN', entityId: other.user.id }),
    );

    // SUPPORT lacks staff.write: approving a role grant is refused before any lookup.
    const denied = await request(app.getHttpServer())
      .post(`/v1/ops/role-grants/${missing}/approve`)
      .set('Authorization', `Bearer ${other.accessToken}`)
      .send({ reason: 'approve it' })
      .expect(403);
    expect(denied.body.errorCode).toBe('OPS_PERMISSION_DENIED');
    // Routes without a permission tag still only need an Admin session.
    await request(app.getHttpServer())
      .get('/v1/ops/role-grants')
      .set('Authorization', `Bearer ${other.accessToken}`)
      .expect(200);
    // The super-admin passes the permission check and reaches the handler (unknown grant).
    const rootTry = await request(app.getHttpServer())
      .post(`/v1/ops/role-grants/${missing}/approve`)
      .set('Authorization', `Bearer ${root.accessToken}`)
      .send({ reason: 'approve it' });
    expect(rootTry.status).not.toBe(403);
    // No session at all is still a 401, not a permission error.
    await request(app.getHttpServer()).post(`/v1/ops/role-grants/${missing}/approve`).expect(401);

    // DEC-PROD-045: customer reads need customers.read; FINANCE has none, SUPPORT has read + write.
    await request(app.getHttpServer())
      .get('/v1/ops/customers')
      .set('Authorization', `Bearer ${other.accessToken}`)
      .expect(200);
    const matrix = await request(app.getHttpServer())
      .get('/v1/ops/staff/rbac-matrix')
      .set('Authorization', `Bearer ${other.accessToken}`)
      .expect(200);
    expect(matrix.body.data.grants.SUPPORT).toEqual(
      expect.arrayContaining(['customers.read', 'customers.write']),
    );
    expect(matrix.body.data.grants.FINANCE).not.toContain('customers.write');
    await request(app.getHttpServer())
      .post(`/v1/ops/staff/${other.user.id}/staff-role`)
      .set('Authorization', `Bearer ${root.accessToken}`)
      .send({ staffRole: 'FINANCE', reason: 'Chuyển kế toán' })
      .expect(200);
    const financeDenied = await request(app.getHttpServer())
      .get('/v1/ops/customers')
      .set('Authorization', `Bearer ${other.accessToken}`)
      .expect(403);
    expect(financeDenied.body.errorCode).toBe('OPS_PERMISSION_DENIED');
  });
});

