import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../design_system/icons/dealgo_icons.dart';
import '../design_system/tokens/dealgo_tokens.dart';
import '../motion/dealgo_sheet.dart';
import 'app_appearance.dart';

Future<void> showLanguageSheet(BuildContext context) {
  return showDealGoSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final appearance = context.read<AppAppearance>();
      return _OptionSheet(
        title: AppLocalizations.of(context).accountLanguage,
        options: [
          for (final locale in AppAppearance.supportedLocales)
            _Option(
              optionKey: Key('appearance-locale-${locale.languageCode}'),
              label: locale.languageCode == 'en' ? 'English' : 'Tiếng Việt',
              selected: appearance.locale.languageCode == locale.languageCode,
              onTap: () async {
                await appearance.setLocale(locale);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
        ],
      );
    },
  );
}

Future<void> showThemeSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDealGoSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final appearance = context.read<AppAppearance>();
      return _OptionSheet(
        title: l10n.accountTheme,
        options: [
          for (final choice in AppThemeChoice.values)
            _Option(
              optionKey: Key('appearance-theme-${choice.name}'),
              label: themeChoiceLabel(l10n, choice),
              selected: appearance.themeChoice == choice,
              onTap: () async {
                await appearance.setTheme(choice);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
        ],
      );
    },
  );
}

String themeChoiceLabel(AppLocalizations l10n, AppThemeChoice choice) =>
    switch (choice) {
      AppThemeChoice.system => l10n.accountThemeSystem,
      AppThemeChoice.light => l10n.accountThemeLight,
      AppThemeChoice.dark => l10n.accountThemeDark,
    };

String localeLabel(Locale locale) =>
    locale.languageCode == 'en' ? 'English' : 'Tiếng Việt';

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.options});

  final String title;
  final List<_Option> options;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s8,
          DealGoSpacing.s8,
          DealGoSpacing.s8,
          DealGoSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s8,
              ),
              child: Text(title, style: textTheme.titleMedium),
            ),
            for (final option in options) option,
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.optionKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key optionKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: optionKey,
      title: Text(label),
      trailing: selected
          ? const Icon(DealGoIcons.check, color: DealGoColors.primary)
          : null,
      onTap: onTap,
    );
  }
}
