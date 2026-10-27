/** The KYB shop pin (numbers inside Vietnam's bounding box), else null. */
export function shopPinFromMetadata(
  metadata: Record<string, unknown>,
): { lat: number; lng: number; label: string | null } | null {
  const lat = metadata.shopLat;
  const lng = metadata.shopLng;
  if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }
  if (lat < 8 || lat > 23.5 || lng < 102 || lng > 110) {
    return null;
  }
  const label = typeof metadata.shopAddress === 'string' && metadata.shopAddress.trim() ? metadata.shopAddress.trim() : null;
  return { lat, lng, label };
}
