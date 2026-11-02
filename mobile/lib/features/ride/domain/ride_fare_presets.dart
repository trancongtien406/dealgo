/// One suggested fare. [percent] is a slice of the configurable headroom
/// (the admin max, split in three). [amountVnd] is already on the 1.000đ
/// step and inside the band the server will accept.
class RideFarePreset {
  const RideFarePreset({
    required this.percent,
    required this.amountVnd,
    required this.enabled,
  });

  final int percent;
  final int amountVnd;
  final bool enabled;
}

/// Headroom the chips may use. [configuredPercent] is the admin max
/// (ceiling − 100, or the counter max − 100). The stepped cap can leave a
/// smaller gap, and that smaller gap is the max that still validates.
int fareHeadroomPercent({
  required int baseVnd,
  required int maxVnd,
  int? configuredPercent,
}) {
  if (baseVnd <= 0 || maxVnd <= baseVnd) return 0;
  final fits = ((maxVnd - baseVnd) * 100) ~/ baseVnd;
  final configured = configuredPercent;
  if (configured == null || configured <= 0) return fits;
  return fits < configured ? fits : configured;
}

/// Three slices of [maxHeadroomPercent]: max/3, 2×max/3, and max.
/// 30 → 10, 20, 30. The last entry is the max itself.
List<int> fareRaisePercents(int maxHeadroomPercent) {
  if (maxHeadroomPercent <= 0) return const [];
  final first = (maxHeadroomPercent / 3).round();
  final second = (maxHeadroomPercent * 2 / 3).round();
  final percents = <int>[];
  for (final p in [first, second, maxHeadroomPercent]) {
    if (p > 0 && (percents.isEmpty || percents.last != p)) percents.add(p);
  }
  return percents;
}

/// Round [raw] up to [stepVnd]. The server ceiling is rounded down, so a
/// round-up that passes it is pulled back to the greatest step still ≤ [capVnd].
int fareStepUpWithinCap(num raw, int capVnd, int stepVnd) {
  if (stepVnd <= 0) return raw.round();
  final up = (raw / stepVnd).ceil() * stepVnd;
  if (up <= capVnd) return up;
  final kept = (capVnd ~/ stepVnd) * stepVnd;
  return kept > 0 ? kept : up;
}

/// Suggested raises from [suggestedVnd]. Each amount rounds up to [stepVnd]
/// and stays ≤ [maxBidVnd], so submitting the chip cannot miss the band.
List<RideFarePreset> rideFareRaisePresets({
  required int suggestedVnd,
  required int maxBidVnd,
  int minBidVnd = 0,
  int stepVnd = 1000,
  int? maxHeadroomPercent,
}) {
  if (suggestedVnd <= 0 || stepVnd <= 0) return const [];
  final headroom = fareHeadroomPercent(
    baseVnd: suggestedVnd,
    maxVnd: maxBidVnd,
    configuredPercent: maxHeadroomPercent,
  );
  final seen = <int>{};
  final presets = <RideFarePreset>[];
  for (final percent in fareRaisePercents(headroom)) {
    final raw = suggestedVnd * (100 + percent) / 100;
    final amount = fareStepUpWithinCap(raw, maxBidVnd, stepVnd);
    if (amount <= suggestedVnd || amount > maxBidVnd || amount < minBidVnd) {
      continue;
    }
    if (!seen.add(amount)) continue;
    presets.add(
      RideFarePreset(percent: percent, amountVnd: amount, enabled: true),
    );
  }
  return presets;
}
