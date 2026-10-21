import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../pages/splash_page.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class DealGoWordmark extends StatelessWidget {
  const DealGoWordmark({this.compact = false, super.key});

  /// Smaller mark for [DealGoAppHeader] trailing slots.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = compact
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleLarge;
    final style = base?.copyWith(fontWeight: FontWeight.w800);
    return Text.rich(
      TextSpan(
        style: style,
        children: const [
          TextSpan(
            text: 'Deal',
            style: TextStyle(color: DealGoColors.primary),
          ),
          TextSpan(
            text: 'Go',
            style: TextStyle(color: DealGoColors.brandGreen),
          ),
        ],
      ),
    );
  }
}

/// Plain app-bar back control (chevron, no chrome). Prefer this over custom
/// circled buttons so nested screens stay visually consistent.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).actionBack,
      onPressed: onPressed,
      icon: const Icon(DealGoIcons.back, size: 24),
    );
  }
}

class AuthInfoBanner extends StatelessWidget {
  const AuthInfoBanner({required this.message, this.title, super.key});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              DealGoIcons.shield,
              color: DealGoColors.primary,
              size: 20,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: textTheme.labelLarge?.copyWith(
                        color: DealGoColors.primary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                  ],
                  Text(
                    message,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.text,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthErrorText extends StatelessWidget {
  const AuthErrorText({required this.error, super.key});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      apiErrorText(AppLocalizations.of(context), error),
      key: const Key('auth-error'),
      style: textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.error,
        height: 1.4,
      ),
    );
  }
}

class SessionRestoringPage extends StatelessWidget {
  const SessionRestoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DealGoSplashScreen(autoNavigate: false);
  }
}
