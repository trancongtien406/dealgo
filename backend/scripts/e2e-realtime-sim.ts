/**
 * Local-only realtime E2E simulator (DEC-PROD-031): ride negotiation over socket + driver GPS replay.
 *
 *   cd backend && npm i --no-save socket.io-client@4.8.1   # once
 *   npx tsx scripts/e2e-realtime-sim.ts                     # all scenarios against http://localhost:3011
 *   npx tsx scripts/e2e-realtime-sim.ts --only=CAR_4 --pace=1500 --hold=20000   # slow replay for the simulator
 *   npx tsx scripts/e2e-realtime-sim.ts --customer=+84xxxxxxxxx  # drive a ride for a real dev customer (app on simulator)
 *   npx tsx scripts/e2e-realtime-sim.ts --cleanup            # delete rows created for the sim users
 *
 * Seeds its own users (+8490999xxxx, "E2E Sim …") in the dev DB, mints sessions directly
 * (same as mint-dev-session.ts). Refuses NODE_ENV=production and non-localhost DBs.
 * Never prints tokens.
 */
import { createHash, createHmac, randomBytes, randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { io, type Socket } from 'socket.io-client';
import { PrismaClient } from '../src/generated/prisma/client.js';

// ---------- env / args ----------
for (const raw of existsSync(resolve('.env')) ? readFileSync(resolve('.env'), 'utf8').split('\n') : []) {
  const line = raw.trim();
  if (!line || line.startsWith('#') || !line.includes('=')) continue;
  const eq = line.indexOf('=');
  const k = line.slice(0, eq).trim();
  if (process.env[k] === undefined) process.env[k] = line.slice(eq + 1).trim().replace(/^(['"])(.*)\1$/, '$2');
}
const arg = (n: string) => process.argv.find((a) => a.startsWith(`--${n}=`))?.split('=').slice(1).join('=');
const flag = (n: string) => process.argv.includes(`--${n}`);
const BASE = arg('base') ?? `http://localhost:${process.env.PORT ?? 3011}`;
const PACE = Number(arg('pace') ?? 1100);
const HOLD = Number(arg('hold') ?? 0);
/** Pause after offers arrive (before selection) so the customer app can show them (simulator smoke). */
const OFFER_HOLD = Number(arg('offer-hold') ?? 0);
/** Pause after ride creation, before drivers offer (open the matching screen on the simulator). */
const CREATE_HOLD = Number(arg('create-hold') ?? 0);
/** Pause after the approach replay (driver near pickup, before arrived) for approach-phase screenshots. */
const APPROACH_HOLD = Number(arg('approach-hold') ?? 0);
const ONLY = arg('only');
/** --showcase: presentable Vietnamese names/plates for App Store screenshots (DEV only). */
const SHOWCASE = flag('showcase');
const SHOWCASE_ACTORS: Record<string, { name: string; vehicleType?: string; plate?: string }> = {
  '+84909990011': { name: 'Nguyễn Văn Hùng', vehicleType: 'Honda Vision', plate: '43-D1 123.45' },
  '+84909990012': { name: 'Phạm Minh Tuấn', vehicleType: 'Yamaha Exciter', plate: '43-E1 567.89' },
  '+84909990021': { name: 'Trần Quốc Việt', vehicleType: 'Toyota Vios', plate: '43A-678.90' },
  '+84909990031': { name: 'Bà Mua' },
  '+84909990022': { name: 'Lê Hoàng Nam', vehicleType: 'Hyundai Accent', plate: '43A-246.80' },
};
const DB_URL = process.env.DATABASE_URL ?? '';
if (process.env.NODE_ENV === 'production') throw new Error('refuses NODE_ENV=production');
if (!/@(localhost|127\.0\.0\.1)[:/]/.test(DB_URL)) throw new Error('refuses non-local DATABASE_URL');
if (!/^http:\/\/(localhost|127\.0\.0\.1)/.test(BASE)) throw new Error('refuses non-local API base');
const SECRET = process.env.JWT_ACCESS_SECRET?.trim() || process.env.JWT_SECRET?.trim() || 'dev-only-change-me';
const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: DB_URL }) });

// ---------- result log ----------
type Row = { scenario: string; check: string; pass: boolean; evidence: string };
const rows: Row[] = [];
function check(scenario: string, name: string, pass: boolean, evidence: unknown) {
  const ev = typeof evidence === 'string' ? evidence : JSON.stringify(evidence);
  rows.push({ scenario, check: name, pass, evidence: ev });
  console.log(`${pass ? 'PASS' : 'FAIL'} [${scenario}] ${name} :: ${ev.slice(0, 300)}`);
}
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ---------- users ----------
const SIM = {
  c1: { phone: '+84909990001', name: 'E2E Sim Khách 1' },
  c2: { phone: '+84909990002', name: 'E2E Sim Khách 2 (IDOR)' },
  bike1: { phone: '+84909990011', name: 'E2E Sim Bike 1', cls: 'MOTORBIKE' },
  bike2: { phone: '+84909990012', name: 'E2E Sim Bike 2', cls: 'MOTORBIKE' },
  car1: { phone: '+84909990021', name: 'E2E Sim Car 1', cls: 'CAR_4' },
  car2: { phone: '+84909990022', name: 'E2E Sim Car 2', cls: 'CAR_4' },
  merchant: { phone: '+84909990031', name: 'E2E Sim Quán' },
} as const;
const SIM_STORE_NAME = 'E2E Sim Quán Mì Quảng';
const SHOWCASE_STORE = { name: 'Mì Quảng Bà Mua — Cầu Rồng', addressLabel: 'Gần Cầu Rồng, Hải Châu, Đà Nẵng', item: 'Mì Quảng gà' };
type Actor = { id: string; phone: string; token: string };

async function ensureUser(phone: string, simName: string, cls?: string): Promise<string> {
  const pretty = SHOWCASE ? SHOWCASE_ACTORS[phone] : undefined;
  const displayName = pretty?.name ?? simName;
  const u = await db.user.upsert({
    where: { phone },
    create: { phone, displayName, phoneVerifiedAt: new Date() },
    update: { displayName },
  });
  await db.roleGrant.upsert({
    where: { userId_role: { userId: u.id, role: 'CUSTOMER' } },
    create: { userId: u.id, role: 'CUSTOMER', status: 'ACTIVE' },
    update: { status: 'ACTIVE' },
  });
  if (!cls && !/Quán/.test(displayName)) {
    // Customer-only actors (c1/c2) must not carry partner roles: a phone reused by a manual
    // UI smoke (e.g. approved as CAR_4 driver) would legitimately see NEGOTIATING rides of its
    // class and turn the IDOR check into a false FAIL. Revoke partner grants for SIM customers.
    const revoked = await db.roleGrant.updateMany({
      where: { userId: u.id, role: { in: ['DRIVER', 'MERCHANT'] }, status: 'ACTIVE' },
      data: { status: 'SUSPENDED' },
    });
    if (revoked.count) console.warn(`[fixture] ${phone}: revoked ${revoked.count} partner grant(s) to keep it customer-only`);
  }
  if (cls) {
    await db.roleGrant.upsert({
      where: { userId_role: { userId: u.id, role: 'DRIVER' } },
      create: { userId: u.id, role: 'DRIVER', status: 'ACTIVE' },
      update: { status: 'ACTIVE' },
    });
    const metadata = pretty
      ? { vehicleClassCode: cls, vehicleType: pretty.vehicleType, plateNumber: pretty.plate, plate: pretty.plate, simulated: true }
      : { vehicleClassCode: cls, plate: `SIM-${phone.slice(-3)}`, simulated: true };
    await db.partnerApplication.upsert({
      where: { userId_role: { userId: u.id, role: 'DRIVER' } },
      create: { userId: u.id, role: 'DRIVER', status: 'APPROVED', metadata, submittedAt: new Date(), reviewedAt: new Date() },
      update: { status: 'APPROVED', metadata },
    });
  }
  return u.id;
}

async function mint(userId: string, phone: string): Promise<Actor> {
  const session = await db.session.create({
    data: {
      userId,
      familyId: randomUUID(),
      channel: 'CUSTOMER',
      refreshTokenHash: createHash('sha256').update(randomBytes(32).toString('base64url')).digest('base64url'),
      expiresAt: new Date(Date.now() + 3600_000),
    },
  });
  const b = (v: unknown) => Buffer.from(JSON.stringify(v)).toString('base64url');
  const iat = Math.floor(Date.now() / 1000);
  const head = `${b({ alg: 'HS256', typ: 'JWT' })}.${b({ sub: userId, sid: session.id, ch: 'customer', iat, exp: iat + 3600 })}`;
  return { id: userId, phone, token: `${head}.${createHmac('sha256', SECRET).update(head).digest('base64url')}` };
}

// ---------- http ----------
let getCount = 0;
async function api(a: Actor, method: string, path: string, body?: unknown, idem = false) {
  if (method === 'GET') getCount++;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${a.token}`,
      'content-type': 'application/json',
      ...(idem ? { 'idempotency-key': randomUUID() } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  let json: any = null;
  try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, body: json?.data ?? json };
}

// ---------- sockets ----------
type Ev = { name: string; at: number; payload: any };
type Sock = { s: Socket; events: Ev[]; reconnects: number };
async function connect(a: Actor): Promise<Sock> {
  const s = io(BASE, { auth: { token: a.token }, transports: ['websocket'], reconnection: false });
  const out: Sock = { s, events: [], reconnects: 0 };
  s.onAny((name, payload) => out.events.push({ name, at: Date.now(), payload }));
  await new Promise<void>((ok, bad) => {
    s.once('connect', () => ok());
    s.once('connect_error', (e) => bad(e));
  });
  return out;
}
function sub(k: Sock, room: string): Promise<any> {
  // Acks come in the API envelope: { success, data: { ok, room | code } }.
  return k.s.timeout(4000).emitWithAck('subscribe', { room }).then((r: any) => r?.data ?? r).catch((e) => ({ ok: false, code: String(e) }));
}

// ---------- geo ----------
const R = 6_371_000;
const rad = (d: number) => (d * Math.PI) / 180;
function dist(a: [number, number], b: [number, number]) { // [lng,lat]
  const dLat = rad(b[1] - a[1]); const dLng = rad(b[0] - a[0]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a[1])) * Math.cos(rad(b[1])) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}
function bearing(a: [number, number], b: [number, number]) {
  const y = Math.sin(rad(b[0] - a[0])) * Math.cos(rad(b[1]));
  const x = Math.cos(rad(a[1])) * Math.sin(rad(b[1])) - Math.sin(rad(a[1])) * Math.cos(rad(b[1])) * Math.cos(rad(b[0] - a[0]));
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}
/** Resample a polyline to ~stepM spacing so replay speed stays plausible (< 70 m/s guard). */
function resample(coords: [number, number][], stepM: number): [number, number][] {
  const out: [number, number][] = [coords[0]!];
  let carry = 0;
  for (let i = 1; i < coords.length; i++) {
    const a = coords[i - 1]!; const b = coords[i]!; const d = dist(a, b);
    let t = stepM - carry;
    while (t <= d) { out.push([a[0] + ((b[0] - a[0]) * t) / d, a[1] + ((b[1] - a[1]) * t) / d]); t += stepM; }
    carry = (carry + d) % stepM;
  }
  out.push(coords[coords.length - 1]!);
  return out;
}

const PICKUP = { lat: 16.0544, lng: 108.2022, label: SHOWCASE ? 'Cầu Rồng, Hải Châu' : 'E2E Sim — Cầu Rồng (đón)' };
const DROPOFF = { lat: 16.0439, lng: 108.1994, label: SHOWCASE ? 'Sân bay Quốc tế Đà Nẵng' : 'E2E Sim — Sân bay Đà Nẵng (đến)' };

async function routeCoords(a: Actor, from: typeof PICKUP, to: typeof PICKUP) {
  const r = await api(a, 'GET', `/v1/rides/route?fromLat=${from.lat}&fromLng=${from.lng}&toLat=${to.lat}&toLng=${to.lng}`);
  const coords = r.body?.coords ?? r.body?.route?.coords;
  if (r.status === 200 && Array.isArray(coords) && coords.length >= 2) {
    const norm = coords.map((c: any) => (Array.isArray(c) ? [c[1], c[0]] : [c.lng, c.lat]) /* API sends [lat,lng] */) as [number, number][];
    return { provider: r.body.provider ?? 'unknown', coords: norm, distanceM: r.body.distanceM };
  }
  return { provider: `fallback-straight (route ${r.status})`, coords: [[from.lng, from.lat], [to.lng, to.lat]] as [number, number][], distanceM: null };
}

async function report(d: Actor, p: [number, number], extra: Record<string, unknown> = {}) {
  return api(d, 'POST', '/v1/me/presence/location', { lat: p[1], lng: p[0], recordedAt: new Date().toISOString(), accuracyM: 8, ...extra });
}

/** Replay points at PACE ms; returns the fixes the server accepted. */
async function replay(sc: string, d: Actor, pts: [number, number][], label: string) {
  const accepted: { lat: number; lng: number; at: string }[] = [];
  const reasons: Record<string, number> = {};
  let lastPolicy: any = null;
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i]!; const n = pts[Math.min(i + 1, pts.length - 1)]!;
    const speedMps = i === 0 ? 0 : dist(pts[i - 1]!, p) / (PACE / 1000);
    const r = await report(d, p, { heading: Math.round(bearing(p, n)) % 360, speedMps: Math.round(speedMps * 10) / 10 });
    lastPolicy = r.body?.policy ?? lastPolicy;
    if (r.body?.accepted) accepted.push({ lat: r.body.lat, lng: r.body.lng, at: r.body.at });
    else reasons[r.body?.reason ?? `HTTP${r.status}`] = (reasons[r.body?.reason ?? `HTTP${r.status}`] ?? 0) + 1;
    await sleep(PACE);
  }
  check(sc, `${label}: replay ${pts.length} điểm`, accepted.length >= pts.length - 1, { accepted: accepted.length, rejected: reasons, policy: lastPolicy });
  return { accepted, policy: lastPolicy };
}

// ---------- ride scenario ----------
async function rideScenario(cls: 'MOTORBIKE' | 'CAR_4', c1: Actor, c2: Actor, win: Actor, lose: Actor, wrong: Actor) {
  const sc = `RIDE ${cls}`;
  const offered = cls === 'MOTORBIKE' ? 30000 : 80000;
  for (const d of [win, lose, wrong]) {
    const p = await api(d, 'POST', '/v1/me/presence', { online: true, rideEnabled: true, foodEnabled: false, lat: PICKUP.lat + 0.004, lng: PICKUP.lng + 0.003 });
    if (p.status >= 300) check(sc, `presence ${d.phone}`, false, p);
  }
  const route = await routeCoords(c1, PICKUP, DROPOFF);
  check(sc, 'route geometry từ API', route.coords.length > 2, { provider: route.provider, points: route.coords.length, distanceM: route.distanceM });

  const cs = await connect(c1);
  const created = await api(c1, 'POST', '/v1/rides', { pickup: PICKUP, dropoff: DROPOFF, offeredFareVnd: offered, vehicleClassCode: cls }, true);
  const rideId: string = created.body?.id;
  check(sc, 'khách tạo ride', created.status === 200 && !!rideId, { status: created.status, rideId, rideStatus: created.body?.status, cls: created.body?.vehicleClassCode });
  if (!rideId) { cs.s.close(); return; }
  const subs = await Promise.all([sub(cs, `ride:${rideId}`), sub(cs, `ride-offers:${rideId}`), sub(cs, `ride-location:${rideId}`)]);
  check(sc, 'khách join ride/ride-offers/ride-location', subs.every((x) => x?.ok), subs);

  // open list per class
  const openWin = await api(win, 'GET', '/v1/rides/open');
  const openWrong = await api(wrong, 'GET', '/v1/rides/open');
  const ids = (b: any) => (Array.isArray(b) ? b : b?.items ?? []).map((r: any) => r.id);
  check(sc, 'tài xế đúng class thấy ride trong /open', ids(openWin.body).includes(rideId), { status: openWin.status, n: ids(openWin.body).length });
  check(sc, 'tài xế sai class KHÔNG thấy ride', !ids(openWrong.body).includes(rideId), { status: openWrong.status, n: ids(openWrong.body).length });
  const wrongOffer = await api(wrong, 'POST', `/v1/rides/${rideId}/offers`, { amountVnd: offered });
  check(sc, 'tài xế sai class bị chặn offer', wrongOffer.status === 403, { status: wrongOffer.status, code: wrongOffer.body?.code ?? wrongOffer.body?.error?.code });

  if (CREATE_HOLD) { console.log(`SMOKE ride=${rideId} created; hold ${CREATE_HOLD}ms before offers…`); await sleep(CREATE_HOLD); }
  // drivers listen on ride room (offering drivers may join it)
  const ws = await connect(win); const ls = await connect(lose);
  const t0 = Date.now();
  const o1 = await api(win, 'POST', `/v1/rides/${rideId}/offers`, { amountVnd: offered });
  const o2 = await api(lose, 'POST', `/v1/rides/${rideId}/offers`, { amountVnd: offered + 5000 });
  check(sc, '2 tài xế gửi offer (accept + counter)', o1.status === 200 && o2.status === 200, { win: o1.status, lose: o2.status, loseErr: o2.status !== 200 ? o2.body : undefined });
  const wsub = await sub(ws, `ride:${rideId}`); const lsub = await sub(ls, `ride:${rideId}`);
  check(sc, 'tài xế đã offer join được ride:<id>', !!wsub?.ok && !!lsub?.ok, { wsub, lsub });
  await sleep(800);
  const offerEvs = cs.events.filter((e) => e.name === 'rideOffers' && e.payload?.rideId === rideId);
  const lastOffers = offerEvs.at(-1)?.payload?.offers ?? [];
  check(sc, 'khách nhận rideOffers realtime', offerEvs.length >= 2 && lastOffers.length >= 2, {
    events: offerEvs.length, latencyMs: offerEvs[0] ? offerEvs[0].at - t0 : null,
    offers: lastOffers.map((o: any) => ({ kind: o.kind, amountVnd: o.amountVnd, status: o.status })),
  });

  if (OFFER_HOLD) { console.log(`SMOKE ride=${rideId} offers sent; hold ${OFFER_HOLD}ms before selection…`); await sleep(OFFER_HOLD); }
  // IDOR before selection
  const loseOffersSub = await sub(ls, `ride-offers:${rideId}`);
  const loseLocSub = await sub(ls, `ride-location:${rideId}`);
  const c2s = await connect(c2);
  const idor = await Promise.all([sub(c2s, `ride:${rideId}`), sub(c2s, `ride-offers:${rideId}`), sub(c2s, `ride-location:${rideId}`)]);
  const c2get = await api(c2, 'GET', `/v1/rides/${rideId}`);
  const c2loc = await api(c2, 'GET', `/v1/rides/${rideId}/driver-location`);
  check(sc, 'IDOR: tài xế khác KHÔNG join ride-offers/ride-location', !loseOffersSub?.ok && !loseLocSub?.ok, { loseOffersSub, loseLocSub });
  check(sc, 'IDOR: khách khác KHÔNG join ride/ride-offers/ride-location + REST chặn', idor.every((x) => !x?.ok) && c2get.status >= 403 && c2loc.status >= 403, { idor, get: c2get.status, loc: c2loc.status });

  // selection
  const view = await api(c1, 'GET', `/v1/rides/${rideId}`);
  const offers: any[] = view.body?.offers ?? lastOffers;
  const winOffer = offers.find((o) => o.driverId === win.id) ?? offers[0];
  const sel = await api(c1, 'POST', `/v1/rides/${rideId}/selection`, { offerId: winOffer?.id }, true);
  check(sc, 'khách chọn offer tài xế 1', sel.status === 200 && sel.body?.status === 'ASSIGNED', { status: sel.status, rideStatus: sel.body?.status, driver: sel.body?.assignedDriverId === win.id });
  // Outbox relay polls every OUTBOX_RELAY_INTERVAL_MS (2s) → wait up to 10s for both drivers' snapshots.
  for (let t = 0; t < 20; t++) {
    const got = (sk: typeof ws) => sk.events.some((e) => e.name === 'snapshot' && e.payload?.aggregateId === rideId);
    if (got(ws)) break;
    await sleep(500);
  }
  const afterSel = cs.events.filter((e) => e.name === 'rideOffers' && e.payload?.rideId === rideId).at(-1)?.payload;
  check(sc, 'rideOffers sau chọn: SELECTED/LOST', !!afterSel && afterSel.offers.some((o: any) => o.status === 'SELECTED') && afterSel.offers.some((o: any) => o.status === 'LOST'), afterSel?.offers?.map((o: any) => o.status));
  const winSnap = ws.events.filter((e) => e.name === 'snapshot' && e.payload?.aggregateId === rideId).map((e) => e.payload.status);
  const loseSnap = ls.events.filter((e) => e.name === 'snapshot' && e.payload?.aggregateId === rideId).map((e) => e.payload.status);
  const loseGet = await api(lose, 'GET', `/v1/rides/${rideId}`);
  const loseLoc = await api(lose, 'POST', `/v1/rides/${rideId}/en-route`);
  check(sc, 'tài xế được chọn nhận snapshot ASSIGNED', winSnap.includes('ASSIGNED'), winSnap);
  check(sc, 'tài xế bị loại: bị kick khỏi ride:<id> (0 snapshot sau selection) + không đọc/điều khiển được ride', loseSnap.filter((st) => st !== 'NEGOTIATING').length === 0 && loseGet.status >= 403 && loseLoc.status >= 403, { loseSnap, get: loseGet.status, enRoute: loseLoc.status, leakedLocationEvents: ls.events.filter((e) => e.name === 'driverLocation').length });
  const loseRejoin = await sub(ls, `ride:${rideId}`);
  check(sc, 'tài xế bị loại KHÔNG join lại ride:<id>', !loseRejoin?.ok, loseRejoin);

  // en route: approach pickup from the driver's start
  const er = await api(win, 'POST', `/v1/rides/${rideId}/en-route`);
  check(sc, 'en-route', er.status === 200, { status: er.status, rideStatus: er.body?.status });
  const approach = resample([[PICKUP.lng + 0.003, PICKUP.lat + 0.004], [PICKUP.lng, PICKUP.lat]], 11);
  const locStart = cs.events.length;
  const rep1 = await replay(sc, win, approach, 'đến điểm đón');
  check(sc, 'policy ON_TRIP khi đang có cuốc', rep1.policy?.mode === 'ON_TRIP', rep1.policy);

  // bad fixes (none must reach the customer)
  const here = approach.at(-1)!;
  await sleep(1100);
  const bad = {
    stale: await report(win, here, { recordedAt: new Date(Date.now() - 180_000 /* > DRIVER_LOCATION_FRESH_MS (2 min) */).toISOString() }),
  };
  await sleep(1100);
  const lowAcc = await report(win, here, { accuracyM: 500 }); await sleep(1100);
  const jump = await report(win, [here[0] + 0.02, here[1] + 0.02]); await sleep(1100);
  const future = await report(win, here, { recordedAt: new Date(Date.now() + 120_000).toISOString() }); await sleep(1100);
  const okFix = await report(win, here);
  const spam = await report(win, here);
  const reasons = { stale: bad.stale.body?.reason, lowAccuracy: lowAcc.body?.reason, jump: jump.body?.reason, future: future.body?.reason, okFix: okFix.body?.accepted, spam: spam.body?.reason };
  check(sc, 'bản tin xấu bị loại (STALE/LOW_ACCURACY/IMPLAUSIBLE_JUMP/FUTURE/RATE_LIMITED)',
    reasons.stale === 'STALE' && reasons.lowAccuracy === 'LOW_ACCURACY' && reasons.jump === 'IMPLAUSIBLE_JUMP' && reasons.future === 'FUTURE' && reasons.okFix === true && reasons.spam === 'RATE_LIMITED', reasons);

  if (APPROACH_HOLD) { console.log(`SMOKE ride=${rideId} approach; hold ${APPROACH_HOLD}ms before arrived…`); await sleep(APPROACH_HOLD); }
  const ar = await api(win, 'POST', `/v1/rides/${rideId}/arrived`);
  check(sc, 'arrived', ar.status === 200, { status: ar.status, rideStatus: ar.body?.status });

  // reconnect: drop socket, reconnect, resubscribe, one REST snapshot
  cs.s.close();
  const g0 = getCount;
  const cs2 = await connect(c1);
  const re = await Promise.all([sub(cs2, `ride:${rideId}`), sub(cs2, `ride-location:${rideId}`), sub(cs2, `ride-offers:${rideId}`)]);
  const snap = await api(c1, 'GET', `/v1/rides/${rideId}/driver-location`);
  check(sc, 'reconnect → resubscribe + 1 REST snapshot', re.every((x) => x?.ok) && snap.status === 200 && getCount - g0 === 1, { resub: re.map((x) => x?.ok), snapshotStatus: snap.status, snapshot: snap.body, restGets: getCount - g0 });
  const code = (await api(c1, 'GET', `/v1/rides/${rideId}`)).body?.pickupCode;
  const wrongCode = await api(win, 'POST', `/v1/rides/${rideId}/start`, { pickupCode: code === '0000' ? '1111' : '0000' });
  const st = await api(win, 'POST', `/v1/rides/${rideId}/start`, { pickupCode: code });
  check(sc, 'start (sai mã bị chặn, đúng mã OK)', wrongCode.status >= 400 && st.status === 200, { wrong: wrongCode.status, start: st.status, rideStatus: st.body?.status });

  // in trip: replay along the Mapbox route
  const tripPts = resample(route.coords, cls === 'MOTORBIKE' ? 11 : 14);
  const tripSample = tripPts.slice(0, Math.min(tripPts.length, Number(arg('trip-points') ?? 25)));
  await sleep(1100);
  if (HOLD) console.log(`SMOKE ride=${rideId} IN_TRIP replay starting`);
  const rep2 = await replay(sc, win, tripSample, 'dọc tuyến Mapbox (IN_TRIP)');
  if (HOLD) { console.log(`hold ${HOLD}ms for screenshots…`); await sleep(HOLD); }
  const done = await api(win, 'POST', `/v1/rides/${rideId}/complete`);
  check(sc, 'complete', done.status === 200, { status: done.status, rideStatus: done.body?.status });

  // location assertions
  const locs = [...cs.events.slice(locStart), ...cs2.events].filter((e) => e.name === 'driverLocation');
  const wrongRoom = locs.filter((e) => e.payload?.aggregateId !== rideId).length;
  const ats = locs.map((e) => Date.parse(e.payload.at));
  const gaps = ats.slice(1).map((t, i) => t - ats[i]!);
  const ordered = gaps.every((g) => g > 0);
  const minGap = gaps.length ? Math.min(...gaps) : null;
  const badLeak = locs.filter((e) => Math.abs(e.payload.lat - (here[1] + 0.02)) < 1e-6).length;
  const withMotion = locs.filter((e) => typeof e.payload.heading === 'number').length;
  check(sc, 'khách nhận driverLocation đúng room + có heading/speed', locs.length > 0 && wrongRoom === 0 && withMotion > 0, { received: locs.length, accepted: rep1.accepted.length + rep2.accepted.length + 1, wrongRoom, withHeading: withMotion });
  check(sc, 'thứ tự tăng dần + throttle ≥2000ms', ordered && (minGap ?? 0) >= 2000, { minGapMs: minGap, maxGapMs: gaps.length ? Math.max(...gaps) : null });
  check(sc, 'bản tin xấu KHÔNG tới khách', badLeak === 0, { leaked: badLeak });
  const loseAfterSel = ls.events.filter((e) => e.name === 'snapshot' && e.payload?.aggregateId === rideId && e.payload?.status !== 'NEGOTIATING').map((e) => e.payload.status);
  check(sc, 'tài xế bị loại nhận 0 snapshot sau selection (cả chuyến)', loseAfterSel.length === 0, { loseAfterSel });
  check(sc, 'tài xế bị loại không nhận driverLocation', ls.events.filter((e) => e.name === 'driverLocation').length === 0 && c2s.events.filter((e) => e.name === 'driverLocation' || e.name === 'rideOffers').length === 0, { lose: ls.events.map((e) => e.name), c2: c2s.events.map((e) => e.name) });
  for (const k of [cs2, ws, ls, c2s]) k.s.close();
  for (const d of [win, lose, wrong]) await api(d, 'POST', '/v1/me/presence', { online: false });
  return rideId;
}


// ---------- food scenario ----------
async function ensureSimStore(ownerId: string) {
  await db.roleGrant.upsert({
    where: { userId_role: { userId: ownerId, role: 'MERCHANT' } },
    create: { userId: ownerId, role: 'MERCHANT', status: 'ACTIVE' },
    update: { status: 'ACTIVE' },
  });
  let store = await db.foodStore.findFirst({ where: { ownerId, name: { in: [SIM_STORE_NAME, SHOWCASE_STORE.name] } } });
  if (!store) {
    store = await db.foodStore.create({
      data: { ownerId, name: SIM_STORE_NAME, category: 'noodles', lat: PICKUP.lat, lng: PICKUP.lng, addressLabel: 'E2E Sim — Cầu Rồng' },
    });
  }
  // --showcase renames for screenshots; a normal run restores the E2E names.
  const look = SHOWCASE ? SHOWCASE_STORE : { name: SIM_STORE_NAME, addressLabel: 'E2E Sim — Cầu Rồng', item: 'E2E Sim Mì Quảng gà' };
  store = await db.foodStore.update({ where: { id: store.id }, data: { name: look.name, addressLabel: look.addressLabel } });
  let item = await db.foodItem.findFirst({ where: { storeId: store.id } });
  if (!item) item = await db.foodItem.create({ data: { storeId: store.id, name: look.item, priceVnd: 45000 } });
  else if (item.name !== look.item) item = await db.foodItem.update({ where: { id: item.id }, data: { name: look.item } });
  return { storeId: store.id, itemId: item.id };
}

async function foodScenario(c1: Actor, c2: Actor, merchant: Actor, courier: Actor, other: Actor) {
  const sc = 'FOOD';
  const { storeId, itemId } = await ensureSimStore(merchant.id);
  for (const d of [courier, other]) {
    const p = await api(d, 'POST', '/v1/me/presence', { online: true, rideEnabled: false, foodEnabled: true, lat: PICKUP.lat + 0.003, lng: PICKUP.lng + 0.002 });
    if (p.status >= 300) check(sc, `presence ${d.phone}`, false, p);
  }
  const route = await routeCoords(c1, PICKUP, DROPOFF);
  const quote = await api(c1, 'POST', '/v1/food/quote', { storeId, dropoff: DROPOFF });
  check(sc, 'quote phí giao', quote.status === 200, { status: quote.status, body: quote.body });
  const cs = await connect(c1);
  const placed = await api(c1, 'POST', '/v1/food/orders', { storeId, items: [{ itemId, quantity: 2 }], dropoff: DROPOFF, deliveryFareVnd: quote.body?.deliveryFareVnd ?? quote.body?.fareVnd }, true);
  const orderId: string = placed.body?.id;
  check(sc, 'khách đặt món', placed.status === 200 && !!orderId, { status: placed.status, orderStatus: placed.body?.status, total: placed.body?.totalVnd, err: placed.status !== 200 ? placed.body : undefined });
  if (!orderId) { cs.s.close(); return; }
  if (CREATE_HOLD) { console.log(`SMOKE food=${orderId} placed; hold ${CREATE_HOLD}ms…`); await sleep(CREATE_HOLD); }
  const subs = await Promise.all([sub(cs, `food:${orderId}`), sub(cs, `food-location:${orderId}`)]);
  check(sc, 'khách join food:<id> + food-location:<id>', subs.every((x) => x?.ok), subs);
  const ms = await connect(merchant);
  const storeSub = await sub(ms, `store:${storeId}`);
  check(sc, 'quán join store:<id>', !!storeSub?.ok, storeSub);
  // IDOR
  const c2s = await connect(c2);
  const idor = await Promise.all([sub(c2s, `food:${orderId}`), sub(c2s, `food-location:${orderId}`), sub(c2s, `store:${storeId}`)]);
  const c2Get = await api(c2, 'GET', `/v1/food/orders/${orderId}`);
  const c2Loc = await api(c2, 'GET', `/v1/food/orders/${orderId}/driver-location`);
  check(sc, 'IDOR: khách khác bị chặn socket + REST', idor.every((x) => !x?.ok) && c2Get.status >= 403 && c2Loc.status >= 403, { socket: idor.map((x) => x?.code), get: c2Get.status, loc: c2Loc.status });
  const courierEarly = await api(courier, 'POST', `/v1/food/orders/${orderId}/claim`);
  check(sc, 'shipper không nhận được khi quán chưa xong', courierEarly.status >= 400, { status: courierEarly.status, code: courierEarly.body?.code ?? courierEarly.body?.error?.code });
  const acc = await api(merchant, 'POST', `/v1/food/orders/${orderId}/accept`);
  check(sc, 'quán nhận đơn (PREPARING)', acc.status === 200 && acc.body?.status === 'PREPARING', { status: acc.status, orderStatus: acc.body?.status, err: acc.status !== 200 ? acc.body : undefined });
  const rdy = await api(merchant, 'POST', `/v1/food/orders/${orderId}/ready`);
  check(sc, 'quán báo xong (READY)', rdy.status === 200 && rdy.body?.status === 'READY', { status: rdy.status, orderStatus: rdy.body?.status });
  const ready = await api(courier, 'GET', `/v1/food/orders/ready?lat=${PICKUP.lat}&lng=${PICKUP.lng}`);
  const readyIds = (Array.isArray(ready.body) ? ready.body : ready.body?.items ?? []).map((o: any) => o.id);
  // Dispatch list is FIFO (oldest-first, capped at DISPATCH_FALLBACK_LIMIT); dev seed keeps a READY backlog nearby.
  const mine = await db.foodOrder.findUnique({ where: { id: orderId }, select: { createdAt: true } });
  const olderBacklog = await db.foodOrder.count({ where: { status: 'READY', assignedDriverId: null, createdAt: { lt: mine!.createdAt } } });
  const fifoOk = readyIds.length > 0 && !readyIds.includes(orderId) && olderBacklog >= readyIds.length;
  check(sc, 'shipper thấy đơn trong /orders/ready (hoặc FIFO bị backlog cũ hơn che)', ready.status === 200 && (readyIds.includes(orderId) || fifoOk), { status: ready.status, n: readyIds.length, included: readyIds.includes(orderId), olderBacklog });
  const cl = await api(courier, 'POST', `/v1/food/orders/${orderId}/claim`);
  const cl2 = await api(other, 'POST', `/v1/food/orders/${orderId}/claim`);
  check(sc, 'shipper nhận đơn (ASSIGNED), shipper khác bị từ chối', cl.status === 200 && cl.body?.status === 'ASSIGNED' && cl2.status >= 400, { claim: cl.status, orderStatus: cl.body?.status, other: cl2.status });
  const os = await connect(other);
  const otherSub = await Promise.all([sub(os, `food:${orderId}`), sub(os, `food-location:${orderId}`)]);
  check(sc, 'IDOR: shipper khác không join food/food-location', otherSub.every((x) => !x?.ok), otherSub.map((x) => x?.code));
  // courier → store
  const toStore = resample([[PICKUP.lng + 0.002, PICKUP.lat + 0.003], [PICKUP.lng, PICKUP.lat]], 11);
  const locStart = cs.events.length;
  await replay(sc, courier, toStore, 'shipper tới quán');
  const view = await api(merchant, 'GET', `/v1/food/orders/${orderId}`);
  const pu = await api(courier, 'POST', `/v1/food/orders/${orderId}/pickup`, view.body?.handoverCode ? { handoverCode: view.body.handoverCode } : {});
  check(sc, 'pickup (PICKED_UP)', pu.status === 200 && pu.body?.status === 'PICKED_UP', { status: pu.status, orderStatus: pu.body?.status, handoverRequired: !!view.body?.handoverCode });
  // reconnect mid-delivery
  cs.s.close();
  const g0 = getCount;
  const cs2 = await connect(c1);
  const re = await Promise.all([sub(cs2, `food:${orderId}`), sub(cs2, `food-location:${orderId}`)]);
  const snap = await api(c1, 'GET', `/v1/food/orders/${orderId}/driver-location`);
  check(sc, 'reconnect → resubscribe + 1 REST snapshot', re.every((x) => x?.ok) && snap.status === 200 && getCount - g0 === 1, { resub: re.map((x) => x?.ok), snapshot: snap.body, restGets: getCount - g0 });
  const pts = resample(route.coords, 11).slice(0, Number(arg('trip-points') ?? 25));
  await sleep(1100);
  if (HOLD) console.log(`SMOKE food=${orderId} delivery replay starting`);
  const rep = await replay(sc, courier, pts, 'dọc tuyến Mapbox (PICKED_UP)');
  if (HOLD) { console.log(`hold ${HOLD}ms for screenshots…`); await sleep(HOLD); }
  const custView = await api(c1, 'GET', `/v1/food/orders/${orderId}`);
  const code = custView.body?.deliveryCode;
  const bad = await api(courier, 'POST', `/v1/food/orders/${orderId}/deliver`, { deliveryCode: code === '0000' ? '1111' : '0000' });
  const dl = await api(courier, 'POST', `/v1/food/orders/${orderId}/deliver`, code ? { deliveryCode: code } : {});
  check(sc, 'giao xong (sai mã bị chặn, đúng mã DELIVERED)', (!code || bad.status >= 400) && dl.status === 200 && dl.body?.status === 'DELIVERED', { codeRequired: !!code, wrong: bad.status, deliver: dl.status, orderStatus: dl.body?.status, err: dl.status !== 200 ? dl.body : undefined });
  await sleep(4500);
  const locs = [...cs.events.slice(locStart), ...cs2.events].filter((e) => e.name === 'driverLocation' && e.payload?.aggregateId === orderId);
  check(sc, 'khách nhận driverLocation qua food-location', locs.length >= Math.min(5, rep.accepted.length / 2) && locs.every((e) => e.payload.aggregateType === 'FoodOrder'), { received: locs.length, accepted: rep.accepted.length });
  const custSnaps = [...cs.events, ...cs2.events].filter((e) => e.name === 'snapshot' && e.payload?.aggregateId === orderId).map((e) => e.payload.status);
  check(sc, 'khách nhận snapshot trạng thái realtime', custSnaps.includes('PICKED_UP') && custSnaps.includes('DELIVERED'), custSnaps);
  const storeSnaps = ms.events.filter((e) => e.name === 'snapshot' && e.payload?.aggregateId === orderId).map((e) => e.payload.status);
  check(sc, 'quán nhận snapshot trên store:<id>', storeSnaps.length > 0, storeSnaps);
  const leaks = [...c2s.events, ...os.events].filter((e) => e.payload?.aggregateId === orderId);
  check(sc, 'không rò sự kiện sang khách/shipper khác', leaks.length === 0, { leaks: leaks.map((e) => e.name) });
  const after = await api(c1, 'GET', `/v1/food/orders/${orderId}/driver-location`);
  check(sc, 'sau DELIVERED không còn vị trí shipper', after.status !== 200 || !after.body?.location, { status: after.status, location: after.body?.location ?? null });
  for (const k of [cs2, ms, c2s, os]) k.s.close();
  for (const d of [courier, other]) await api(d, 'POST', '/v1/me/presence', { online: false });
  return orderId;
}

// ---------- cleanup ----------
const LEFTOVER_RIDE_IDS = ['08db1201-6950-4eea-a940-5fc4ab703653'];
const LEFTOVER_PRESENCE_PHONES = ['+84903000001']; // seed CAR_7 driver: keep user, reset fake GPS

/** Deletes only E2E Sim data (+ listed dev leftovers) on a localhost DB, children first, in one tx. */
async function cleanup() {
  const url = new URL(process.env.DATABASE_URL ?? '');
  if (!['localhost', '127.0.0.1', '::1'].includes(url.hostname)) {
    throw new Error(`cleanup refused: DATABASE_URL host ${url.hostname} is not local`);
  }
  const apply = flag('apply');
  const simUsers = await db.user.findMany({ where: { phone: { in: Object.values(SIM).map((u) => u.phone) } }, select: { id: true, displayName: true } });
  const bad = simUsers.filter((u) => !(u.displayName ?? '').startsWith('E2E Sim'));
  if (bad.length) throw new Error(`cleanup refused: sim phone owned by non-sim user ${bad.map((u) => u.id).join(',')}`);
  const users = simUsers.map((u) => u.id);
  const ids = async (sql: string, ...p: unknown[]) => ((await db.$queryRawUnsafe(sql, ...p)) as { id: string }[]).map((r) => r.id);
  const stores = await ids(`select id::text id from food_stores where "ownerId"::text = any($1)`, users);
  const rides = await ids(`select id::text id from rides where "customerId"::text = any($1) or "assignedDriverId"::text = any($1) or id::text = any($2)
    or id in (select "rideId" from ride_offers where "driverId"::text = any($1))`, users, LEFTOVER_RIDE_IDS);
  const foods = await ids(`select id::text id from food_orders where "customerId"::text = any($1) or "assignedDriverId"::text = any($1) or "storeId"::text = any($2)`, users, stores);
  const ents = [...rides, ...foods];
  console.log(`cleanup ${apply ? 'APPLY' : 'DRY-RUN'} db=${url.hostname}:${url.port}${url.pathname} users=${users.length} rides=${rides.length} foodOrders=${foods.length} stores=${stores.length}`);
  const steps: [string, string, unknown[]][] = [
    ['ledger_entries', `delete from ledger_entries where "journalId" in (select id from ledger_journals where "entityId"::text = any($1))`, [ents]],
    ['ledger_journals', `delete from ledger_journals where "entityId"::text = any($1)`, [ents]],
    ['job_earnings', `delete from job_earnings where "entityId"::text = any($1) or "driverId"::text = any($2)`, [ents, users]],
    ['payment_intents', `delete from payment_intents where "entityId"::text = any($1)`, [ents]],
    ['promotion_redemptions', `delete from promotion_redemptions where "entityId"::text = any($1) or "userId"::text = any($2)`, [ents, users]],
    ['service_ratings', `delete from service_ratings where "subjectId"::text = any($1) or "raterId"::text = any($2) or "driverId"::text = any($2) or "storeId"::text = any($3)`, [ents, users, stores]],
    ['ops_audit_logs', `delete from ops_audit_logs where "entityId"::text = any($1) or "actorUserId"::text = any($2)`, [ents, users]],
    ['chat_messages', `delete from chat_messages where "senderUserId"::text = any($1) or "threadId" in (select id from chat_threads where "rideId"::text = any($2) or "foodOrderId"::text = any($2))`, [users, ents]],
    ['ride_selections', `delete from ride_selections where "rideId"::text = any($1) or "customerId"::text = any($2)`, [rides, users]],
    ['rides.selectedOfferId=null', `update rides set "selectedOfferId" = null where id::text = any($1)`, [rides]],
    ['ride_offers', `delete from ride_offers where "rideId"::text = any($1) or "driverId"::text = any($2)`, [rides, users]],
    ['rides (cascade pickup_codes/share_links/chat_threads)', `delete from rides where id::text = any($1)`, [rides]],
    ['food_orders (cascade lines/codes/chat_threads)', `delete from food_orders where id::text = any($1)`, [foods]],
    ['food_stores (cascade items/menu/hours)', `delete from food_stores where id::text = any($1)`, [stores]],
    ['driver_fee_settlements', `delete from driver_fee_settlements where "driverId"::text = any($1) or "actorUserId"::text = any($1)`, [users]],
    ['users (cascade sessions/presence/grants/applications/...)', `delete from users where id::text = any($1)`, [users]],
    ['leftover driver_presence -> offline', `update driver_presence set online = false, lat = null, lng = null where "userId" in (select id from users where phone = any($1))`, [LEFTOVER_PRESENCE_PHONES]],
  ];
  const report: Record<string, number> = {};
  try {
    await db.$transaction(async (tx) => {
      for (const [name, sql, p] of steps) report[name] = await tx.$executeRawUnsafe(sql, ...p);
      if (!apply) throw new Error('__dry_run__');
    }, { timeout: 60_000 });
  } catch (e) {
    if (String(e).indexOf('__dry_run__') < 0) throw e;
  }
  console.log(JSON.stringify(report, null, 2));
}

/** UI smoke: give sim drivers an email+password login (random pw kept in a 0600 file, never printed). */
async function uiSetup() {
  const { randomBytes } = await import('node:crypto');
  const { writeFileSync } = await import('node:fs');
  const { hash, argon2id } = await import('argon2');
  const password = `Sim-${randomBytes(9).toString('base64url')}`;
  const passwordHash = await hash(password, { type: argon2id });
  const out: Record<string, string> = { password };
  for (const key of ['bike1', 'car1', 'c1'] as const) {
    const u = SIM[key];
    const id = await ensureUser(u.phone, u.name, (u as any).cls);
    const email = `e2e.sim.${key}@sim.dealgo.local`;
    await db.user.update({ where: { id }, data: { email, emailVerifiedAt: new Date() } });
    await db.customerCredential.upsert({ where: { userId: id }, create: { userId: id, passwordHash }, update: { passwordHash } });
    out[key] = email;
    console.log(`ui-setup ${key} ${email}`);
  }
  writeFileSync('/tmp/e2e-sim-ui.json', JSON.stringify(out), { mode: 0o600 });
}

async function main() {
  if (flag('ui-setup')) { await uiSetup(); return; }
  if (flag('cleanup')) { await cleanup(); return; }
  const a: Record<string, Actor> = {};
  for (const [k, u] of Object.entries(SIM)) a[k] = await mint(await ensureUser(u.phone, u.name, (u as any).cls), u.phone);
  let c1 = a.c1!;
  const real = arg('customer');
  if (real) {
    const u = await db.user.findUnique({ where: { phone: real } });
    if (!u) throw new Error(`customer ${real} not found`);
    c1 = await mint(u.id, real);
  }
  const started = Date.now();
  if (!ONLY || ONLY === 'MOTORBIKE') await rideScenario('MOTORBIKE', c1, a.c2!, a.bike1!, a.bike2!, a.car1!);
  if (!ONLY || ONLY === 'CAR_4') await rideScenario('CAR_4', c1, a.c2!, a.car1!, a.car2!, a.bike1!);
  if (!ONLY || ONLY === 'FOOD') await foodScenario(c1, a.c2!, a.merchant!, a.bike1!, a.bike2!);
  const fail = rows.filter((r) => !r.pass);
  console.log(`\nSUMMARY ${rows.length - fail.length}/${rows.length} PASS in ${Math.round((Date.now() - started) / 1000)}s`);
  if (flag('json')) console.log(JSON.stringify(rows));
  process.exitCode = fail.length ? 1 : 0;
}

main().catch((e) => { console.error(e); process.exitCode = 1; }).finally(() => db.$disconnect());
