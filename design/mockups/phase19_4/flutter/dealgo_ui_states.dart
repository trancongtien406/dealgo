import 'package:flutter/material.dart';

/// DealGo Phase 19.4: UI-only state pattern. No networking or persistence.
/// Connect to a domain BLoC/Cubit and server-authoritative state machine.
enum DealGoUiPhase { initial, loading, content, empty, offline, error, expired, conflict, pending }

enum DealGoUiIntent {
  retry,
  refresh,
  edit,
  openSettings,
  contactSupport,
  cancel,
  confirmNewPrice,
  updateDocument,
}

@immutable
class DealGoUiSnapshot {
  const DealGoUiSnapshot({
    required this.phase,
    required this.heading,
    required this.description,
    this.code,
    this.serverVersion,
    this.lastUpdatedAt,
    this.primaryIntent,
    this.secondaryIntent,
    this.isPrimaryEnabled = true,
  });

  final DealGoUiPhase phase;
  final String heading;
  final String description;
  final String? code;
  final int? serverVersion;
  final DateTime? lastUpdatedAt;
  final DealGoUiIntent? primaryIntent;
  final DealGoUiIntent? secondaryIntent;
  final bool isPrimaryEnabled;
}

abstract final class DealGoColorTokens {
  static const primary = Color(0xFF6D28D9);
  static const primaryPressed = Color(0xFF5820B5);
  static const greenBrand = Color(0xFF16A34A);
  static const greenText = Color(0xFF13743A); // WCAG on white for small text
  static const warningText = Color(0xFF995B0E);
  static const errorText = Color(0xFFC12745);
  static const canvas = Color(0xFFFBFAFD);
  static const text = Color(0xFF171B2C);
  static const muted = Color(0xFF666B80);
  static const stroke = Color(0xFFE7E3EF);
}

/// Wrap the widget inside the screen's existing route, NOT a new route.
/// All labels/actions must be driven by verified domain data.
class DealGoScreenState extends StatelessWidget {
  const DealGoScreenState({
    super.key,
    required this.snapshot,
    required this.actionLabel,
    required this.onIntent,
    this.secondaryActionLabel,
    this.child,
  });

  final DealGoUiSnapshot snapshot;
  final String? actionLabel;
  final String? secondaryActionLabel;
  final void Function(DealGoUiIntent) onIntent;
  final Widget? child;

  IconData get _symbol => switch (snapshot.phase) {
        DealGoUiPhase.loading || DealGoUiPhase.pending => Icons.hourglass_top_rounded,
        DealGoUiPhase.empty => Icons.search_off_rounded,
        DealGoUiPhase.offline => Icons.wifi_off_rounded,
        DealGoUiPhase.expired => Icons.timer_off_outlined,
        DealGoUiPhase.conflict => Icons.sync_problem_rounded,
        DealGoUiPhase.error => Icons.error_outline_rounded,
        _ => Icons.check_circle_outline_rounded,
      };

  Color get _color => switch (snapshot.phase) {
        DealGoUiPhase.error || DealGoUiPhase.expired => DealGoColorTokens.errorText,
        DealGoUiPhase.offline || DealGoUiPhase.conflict => DealGoColorTokens.warningText,
        _ => DealGoColorTokens.primary,
      };

  @override
  Widget build(BuildContext context) {
    final blocked = snapshot.phase == DealGoUiPhase.pending ||
        snapshot.phase == DealGoUiPhase.loading ||
        !snapshot.isPrimaryEnabled;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Semantics(
                        label: snapshot.heading,
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: _color.withValues(alpha: 0.10),
                          child: Icon(_symbol, color: _color, size: 34),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        snapshot.heading,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DealGoColorTokens.muted,
                            ),
                      ),
                      if (snapshot.code != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Mã lỗi ${snapshot.code}',
                          child: Text(
                            snapshot.code!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                      if (child != null) ...[
                        const SizedBox(height: 24),
                        child!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (snapshot.primaryIntent != null && actionLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: blocked ? null : () => onIntent(snapshot.primaryIntent!),
                      child: Text(actionLabel!),
                    ),
                    if (snapshot.secondaryIntent != null &&
                        secondaryActionLabel != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => onIntent(snapshot.secondaryIntent!),
                        child: Text(secondaryActionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
