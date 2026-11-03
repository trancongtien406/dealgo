import 'package:flutter/material.dart';

/// Six text roles for Food surfaces (design spec §4.1).
///
/// The global [TextTheme] is intentionally untouched so other features keep
/// their current scale while Food converges on one hierarchy.
abstract final class DealGoType {
  static TextStyle display(TextTheme text) => text.headlineMedium!.copyWith(
    fontSize: 24,
    height: 28 / 24,
    fontWeight: FontWeight.w700,
  );

  static TextStyle title(TextTheme text) => text.headlineSmall!.copyWith(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
  );

  static TextStyle subtitle(TextTheme text) => text.titleMedium!.copyWith(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
  );

  static TextStyle body(TextTheme text) => text.bodyMedium!.copyWith(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static TextStyle meta(TextTheme text) => text.bodySmall!.copyWith(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  static TextStyle micro(TextTheme text) => text.labelSmall!.copyWith(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
}
