/// t61u: tracks which form values came from on-device OCR and which the
/// applicant changed afterwards (sent as `ocrPrefilled` / `ocrEdited`).
class OcrPrefill {
  const OcrPrefill({
    this.values = const {},
    this.prefilled = const {},
    this.edited = const {},
  });

  /// Last OCR value per key (includes extra keys with no form field yet).
  final Map<String, String> values;
  final Set<String> prefilled;
  final Set<String> edited;

  /// Applies [parsed] over [current] form values. A key is filled only when the
  /// field is empty or still holds an untouched OCR value — never over typing.
  ({OcrPrefill prefill, Map<String, String> apply}) merge(
    Map<String, String> parsed,
    Map<String, String> current,
  ) {
    final apply = <String, String>{};
    final values = {...this.values};
    final prefilled = {...this.prefilled};
    for (final entry in parsed.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      final now = (current[entry.key] ?? '').trim();
      final untouched =
          prefilled.contains(entry.key) && !edited.contains(entry.key);
      if (now.isNotEmpty && !untouched) continue;
      apply[entry.key] = value;
      values[entry.key] = value;
      prefilled.add(entry.key);
    }
    return (
      prefill: OcrPrefill(values: values, prefilled: prefilled, edited: edited),
      apply: apply,
    );
  }

  /// Call from a field setter: marks the key edited when it no longer equals OCR.
  OcrPrefill onEdit(String key, String value) {
    if (!prefilled.contains(key)) return this;
    final same = (values[key] ?? '').trim() == value.trim();
    final next = {...edited};
    same ? next.remove(key) : next.add(key);
    return OcrPrefill(values: values, prefilled: prefilled, edited: next);
  }

  /// Metadata for the submit body; empty when OCR never filled anything.
  /// Admin review (website features/kyc/ocr-fields.ts) reads these keys.
  Map<String, Object?> toMetadata({Iterable<String> extraKeys = const []}) {
    if (prefilled.isEmpty) return const {};
    return {
      for (final key in extraKeys)
        if ((values[key] ?? '').isNotEmpty) key: values[key],
      // Comma lists: the backend keeps only scalar metadata values.
      'ocrPrefilled': (prefilled.toList()..sort()).join(','),
      'ocrEdited': (edited.toList()..sort()).join(','),
    };
  }
}
