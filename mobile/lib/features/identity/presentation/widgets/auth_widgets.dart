import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../pages/splash_page.dart';

class DealGoWordmark extends StatelessWidget {
  const DealGoWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w800);
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

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Quay lại',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: DealGoColors.card,
        foregroundColor: DealGoColors.text,
        fixedSize: const Size(
          DealGoDimensions.minTapTarget,
          DealGoDimensions.minTapTarget,
        ),
        shape: const CircleBorder(side: BorderSide(color: DealGoColors.border)),
      ),
      icon: const Icon(Icons.arrow_back),
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
              Icons.verified_user_outlined,
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
      '${error.errorCode}: ${error.message}',
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
    return const DealGoSplashScreen();
  }
}
