import { HttpException } from '@nestjs/common';

export const RIDE_VEHICLE_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const RIDE_VEHICLE_CLASS_IMAGE_PREFIX = '/v1/public/ride-vehicle-classes';

const CODE_RE = /^[A-Z0-9_]{1,32}$/;
const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp)$/;

export function rideVehicleClassImageError(
  status: number,
  errorCode: string,
  message: string,
): HttpException {
  return new HttpException({ errorCode, message }, status);
}

export function rideVehicleClassImagePath(code: string, key: string): string {
  const file = key.slice(`ride-vehicle-classes/${code}/`.length);
  return `${RIDE_VEHICLE_CLASS_IMAGE_PREFIX}/${code}/${file}`;
}

export function keyFromRideVehicleClassImageUrl(url: string | null | undefined): string | null {
  if (!url?.startsWith(`${RIDE_VEHICLE_CLASS_IMAGE_PREFIX}/`)) {
    return null;
  }
  const rest = url.slice(RIDE_VEHICLE_CLASS_IMAGE_PREFIX.length + 1);
  const slash = rest.indexOf('/');
  if (slash < 0) {
    return null;
  }
  const code = rest.slice(0, slash);
  const file = rest.slice(slash + 1);
  if (!CODE_RE.test(code) || !FILE_RE.test(file)) {
    return null;
  }
  return `ride-vehicle-classes/${code}/${file}`;
}

export function rideVehicleClassImageKey(code: string, file: string): string | null {
  const normalized = code.trim().toUpperCase();
  if (!CODE_RE.test(normalized) || !FILE_RE.test(file)) {
    return null;
  }
  return `ride-vehicle-classes/${normalized}/${file}`;
}

export function resolveVehicleImagePayload(input: {
  contentBase64?: string;
  dataUrl?: string;
  contentType?: string;
}): { base64: string; contentType?: string } | null {
  if (typeof input.dataUrl === 'string' && input.dataUrl.trim()) {
    const match = /^data:([^;,]+)?;base64,(.+)$/i.exec(input.dataUrl.trim());
    return match ? { contentType: match[1] || input.contentType, base64: match[2]! } : null;
  }
  if (typeof input.contentBase64 === 'string' && input.contentBase64.trim()) {
    return { contentType: input.contentType, base64: input.contentBase64.trim() };
  }
  return null;
}
