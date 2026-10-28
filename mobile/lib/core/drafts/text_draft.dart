import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'draft_resume_prompt.dart';
import 'draft_store.dart';

/// App-wide draft wiring (set once in DI). Off until configured, so tests and
/// signed-out screens never persist anything.
abstract final class FormDrafts {
  static DraftStore? store;
  static String? Function()? owner;

  /// Per-user keeper for [scope], or null when drafts are off.
  static DraftKeeper? keeper(String scope, {Duration? maxAge}) {
    final s = store;
    final user = owner?.call()?.trim() ?? '';
    if (s == null || user.isEmpty) {
      return null;
    }
    return DraftKeeper(
      store: s,
      key: 'form.$scope.${base64Url.encode(utf8.encode(user))}',
      maxAge: maxAge ?? const Duration(days: 7),
    );
  }
}

/// Keeps typed text of a form across app kills; restores it silently into
/// fields the user has not touched yet and shows a short note.
mixin TextDraftMixin<T extends StatefulWidget> on State<T> {
  DraftKeeper? _textDraft;
  Map<String, TextEditingController> _textDraftFields = const {};
  Map<String, Object?> Function()? _textDraftExtras;
  var _textDraftListening = false;

  /// Call from initState after the controllers hold their initial values.
  /// Returns the restored values (null when nothing was restored).
  Future<Map<String, String>?> bindTextDraft(
    String scope,
    Map<String, TextEditingController> fields, {
    Duration? maxAge,
    bool showNote = true,
    Map<String, Object?> Function()? extras,
    bool Function(Map<String, Object?> saved)? restoreExtras,
  }) async {
    if (_textDraft != null) {
      return null; // already bound (e.g. a retried load)
    }
    final keeper = FormDrafts.keeper(scope, maxAge: maxAge);
    if (keeper == null) {
      return null;
    }
    _textDraft = keeper;
    _textDraftFields = fields;
    _textDraftExtras = extras;
    final baseline = {for (final e in fields.entries) e.key: e.value.text};
    Map<String, Object?>? saved;
    try {
      saved = await keeper.load();
    } catch (_) {}
    if (!mounted || _textDraft != keeper) {
      return null;
    }
    final restored = <String, String>{};
    if (saved != null) {
      for (final entry in fields.entries) {
        final value = saved[entry.key];
        final controller = entry.value;
        if (value is String &&
            value != controller.text &&
            controller.text == baseline[entry.key]) {
          controller.text = value;
          restored[entry.key] = value;
        }
      }
    }
    var restoredExtras = false;
    if (saved != null && restoreExtras != null) {
      restoredExtras = restoreExtras(saved);
    }
    for (final controller in fields.values) {
      controller.addListener(_saveTextDraft);
    }
    _textDraftListening = true;
    if ((restored.isNotEmpty || restoredExtras) && showNote) {
      showDraftRestoredNote(context);
    }
    return restored.isEmpty ? null : restored;
  }

  void _saveTextDraft() {
    _textDraft?.schedule({
      ...?_textDraftExtras?.call(),
      for (final e in _textDraftFields.entries) e.key: e.value.text,
    });
  }

  /// Saves a non-text value alongside the text (e.g. a picked category).
  void markTextDraftDirty() => _saveTextDraft();

  /// Submit succeeded (or the user explicitly discarded): forget the draft.
  /// Fire-and-forget so navigation never waits on storage; the keeper's
  /// generation guard stops a pending write from resurrecting it.
  void clearTextDraft() {
    _stopTextDraft();
    final keeper = _textDraft;
    _textDraft = null;
    if (keeper != null) unawaited(keeper.clear());
  }

  void _stopTextDraft() {
    if (!_textDraftListening) {
      return;
    }
    _textDraftListening = false;
    for (final controller in _textDraftFields.values) {
      controller.removeListener(_saveTextDraft);
    }
  }

  @override
  void dispose() {
    _stopTextDraft();
    unawaited(_textDraft?.flush());
    super.dispose();
  }
}
