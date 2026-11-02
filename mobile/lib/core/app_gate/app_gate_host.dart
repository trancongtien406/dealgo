import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../design_system/components/dealgo_primary_button.dart';
import '../design_system/components/dealgo_secondary_button.dart';
import '../design_system/icons/dealgo_icons.dart';
import '../design_system/tokens/dealgo_tokens.dart';
import 'app_gate_cubit.dart';
import 'app_gate_models.dart';

typedef OpenExternalUrl = Future<void> Function(String url);

Future<void> _launch(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(
    uri,
    mode: url.contains('apps.apple.com') || url.contains('play.google.com')
        ? LaunchMode.externalApplication
        : LaunchMode.inAppBrowserView,
  );
}

/// t82u: sits above the router (MaterialApp.builder). The app stays mounted
/// underneath; a required update or pending terms cover it completely.
class AppGateHost extends StatelessWidget {
  const AppGateHost({super.key, required this.child, this.openUrl = _launch});

  final Widget child;
  final OpenExternalUrl openUrl;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppGateCubit, AppGateState>(
      builder: (context, gate) {
        // Forced update: full-screen cover. Terms: bottom tray over a
        // visible-but-inert app (owner t85u). Soft update: same tray style,
        // dismissible.
        final Widget? cover = gate.updateRequired
            ? AppUpdateRequiredScreen(info: gate.update, openUrl: openUrl)
            : null;
        final Widget? tray = cover != null
            ? null
            : gate.consentRequired
            ? LegalConsentTray(
                key: const Key('legal-consent-required'),
                state: gate,
                openUrl: openUrl,
              )
            : gate.showOptionalPrompt
            ? _OptionalUpdateCard(info: gate.update, openUrl: openUrl)
            : null;
        final blocking = cover != null || gate.consentRequired;
        return Stack(
          children: [
            // Keep the router alive (and visible under a tray) but inert.
            ExcludeSemantics(
              excluding: blocking,
              child: IgnorePointer(ignoring: blocking, child: child),
            ),
            if (cover != null) Positioned.fill(child: cover),
            if (cover == null && gate.consentRequired)
              const Positioned.fill(
                // Tap-outside does nothing: consent is required.
                child: ModalBarrier(
                  key: Key('legal-consent-scrim'),
                  dismissible: false,
                  color: Color(0x52000000),
                ),
              ),
            if (tray != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GateTray(child: tray),
              ),
          ],
        );
      },
    );
  }
}

/// Rounded bottom tray that slides up; safe-area aware, max ~60% height.
class GateTray extends StatelessWidget {
  const GateTray({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.6;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) =>
          FractionalTranslation(translation: Offset(0, t), child: child),
      child: Material(
        color: DealGoColors.card,
        elevation: 12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoSpacing.s20,
                DealGoSpacing.s20,
                DealGoSpacing.s20,
                DealGoSpacing.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Flexible(child: child)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.icon, required this.children, super.key});

  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DealGoSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.subtlePurple,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(DealGoSpacing.s20),
                        child: Icon(
                          icon,
                          size: 40,
                          color: DealGoColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking "Cập nhật bắt buộc" — no way past it except updating.
class AppUpdateRequiredScreen extends StatelessWidget {
  const AppUpdateRequiredScreen({
    super.key,
    required this.info,
    required this.openUrl,
  });

  final AppUpdateInfo info;
  final OpenExternalUrl openUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return _GateScaffold(
      key: const Key('app-update-required'),
      icon: DealGoIcons.refresh,
      children: [
        Text(
          l10n.appUpdateRequiredTitle,
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Text(
          info.message.isNotEmpty ? info.message : l10n.appUpdateRequiredBody,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: DealGoColors.textSecondary),
        ),
        if (info.latestVersion.isNotEmpty) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            l10n.appUpdateLatest(info.latestVersion),
            textAlign: TextAlign.center,
            style: text.labelLarge,
          ),
        ],
        const SizedBox(height: DealGoSpacing.s24),
        if (info.storeUrl.isNotEmpty)
          DealGoPrimaryButton(
            key: const Key('app-update-now'),
            label: l10n.appUpdateNow,
            onPressed: () => openUrl(info.storeUrl),
          ),
        const SizedBox(height: DealGoSpacing.s8),
        DealGoSecondaryButton(
          key: const Key('app-update-recheck'),
          label: l10n.appUpdateRetry,
          onPressed: () => context.read<AppGateCubit>().checkVersion(),
        ),
      ],
    );
  }
}

class _OptionalUpdateCard extends StatelessWidget {
  const _OptionalUpdateCard({required this.info, required this.openUrl});

  final AppUpdateInfo info;
  final OpenExternalUrl openUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return KeyedSubtree(
      key: const Key('app-update-optional'),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              info.latestVersion.isEmpty
                  ? l10n.appUpdateOptionalTitle
                  : '${l10n.appUpdateOptionalTitle} · ${info.latestVersion}',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              info.message.isNotEmpty
                  ? info.message
                  : l10n.appUpdateOptionalBody,
              style: text.bodyMedium?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: DealGoSecondaryButton(
                    key: const Key('app-update-later'),
                    compact: true,
                    label: l10n.appUpdateLater,
                    onPressed: () =>
                        context.read<AppGateCubit>().dismissOptional(),
                  ),
                ),
                if (info.storeUrl.isNotEmpty) ...[
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoPrimaryButton(
                      compact: true,
                      label: l10n.appUpdateNow,
                      onPressed: () => openUrl(info.storeUrl),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Terms tray: every pending doc in one list, one "Tôi đồng ý".
class LegalConsentTray extends StatelessWidget {
  const LegalConsentTray({
    super.key,
    required this.state,
    required this.openUrl,
  });

  final AppGateState state;
  final OpenExternalUrl openUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final date = DateFormat('dd/MM/yyyy');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(DealGoIcons.shield, color: DealGoColors.primary),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                l10n.legalConsentTitle,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s4),
        Text(
          l10n.legalConsentBody,
          style: text.bodyMedium?.copyWith(color: DealGoColors.textSecondary),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: state.consents.length,
            separatorBuilder: (_, _) =>
                const Divider(height: DealGoSpacing.s20),
            itemBuilder: (context, i) {
              final c = state.consents[i];
              return Column(
                key: Key('legal-consent-${c.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      l10n.legalConsentVersion('${c.version}'),
                      if (c.effectiveAt != null)
                        l10n.legalConsentEffective(
                          date.format(c.effectiveAt!.toLocal()),
                        ),
                    ].join(' · '),
                    style: text.labelMedium?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                  if (c.changelog.isNotEmpty) ...[
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      c.changelog,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ],
                  if (c.url.isNotEmpty)
                    TextButton(
                      key: Key('legal-consent-read-${c.id}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => openUrl(c.url),
                      child: Text(l10n.legalConsentRead),
                    ),
                ],
              );
            },
          ),
        ),
        if (state.acceptFailed) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            l10n.legalConsentFailed,
            key: const Key('legal-consent-failed'),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: DealGoColors.danger),
          ),
        ],
        const SizedBox(height: DealGoSpacing.s12),
        DealGoPrimaryButton(
          key: const Key('legal-consent-agree'),
          label: l10n.legalConsentAgree,
          isLoading: state.accepting,
          onPressed: () => context.read<AppGateCubit>().acceptAll(),
        ),
      ],
    );
  }
}
