# DealGo — Performance & curl matrix (A–E)

Scripts đo latency HTTP của Nest API và seed dữ liệu lớn để stress list/filter paths.

## Prerequisites

- Postgres + Redis (docker-compose DealGo)
- Nest đang chạy (`cd backend && npm run start:dev`) — mặc định `BASE_URL=http://127.0.0.1:3001`
- Demo seed: `cd backend && npm run seed`
- Scale seed (tùy chọn): `PERF_PROFILE=smoke|load|extreme npm run seed:scale`

## Param matrix A–E

| Level | Mục đích | Ví dụ |
|:---|:---|:---|
| **A Minimal** | Hot path / mặc định | `GET /v1/food/stores` |
| **B Single** | Một filter | `?category=cafe` |
| **C Combo** | Combo app thường | `?category=cafe&lat=…&lng=…` |
| **D Full** | Toàn bộ filter handler nhận | `?category&lat&lng&sort_by&search&page&limit` |
| **E Edge** | Trang sâu / rỗng / không token | `page=100`, `search=randomxyz123`, thiếu Bearer → 401 |

**Cố ý bỏ qua:** SMS thật, MoMo/VNPay capture, voice/video (giữ `VOICE_PROVIDER=mock`).

## Commands

```bash
# Mint JWT local (không cần OTP)
cd backend && npx tsx scripts/mint-dev-session.ts --phone=+84902000001

# Full matrix
cd performance
chmod +x run-matrix.sh matrices/*.sh
BASE_URL=http://127.0.0.1:3001 ./run-matrix.sh

# Báo cáo: reports/<RUN_ID>.tsv + .summary.md
```

## Scale seed profiles

| Profile | Users | Stores | Rides | Orders |
|:---|---:|---:|---:|---:|
| `smoke` | 2k | 200 | 10k | 10k |
| `load` | 20k | 2k | 100k | 100k |
| `extreme` | 100k | 10k | **1M** | **1M** |

```bash
cd backend
PERF_PROFILE=smoke npm run seed:scale
PERF_PROFILE=extreme npm run seed:scale   # nặng disk/CPU
```

Prefix dữ liệu: phones `+8499…`, keys `perf:ride:*` / `perf:food:*` — không đụng demo seed.
