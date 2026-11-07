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
              leading: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: locale.languageCode == 'vi'
                      ? DealGoColors.greenSurface
                      : DealGoColors.subtlePurple,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  locale.languageCode == 'vi'
                      ? DealGoIcons.earth
                      : DealGoIcons.languages,
                  size: 18,
                  color: locale.languageCode == 'vi'
                      ? DealGoColors.brandGreen
                      : DealGoColors.primary,
                ),
              ),
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
              leading: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: switch (choice) {
                    AppThemeChoice.system => DealGoColors.subtlePurple,
                    AppThemeChoice.light => DealGoColors.amberSurface,
                    AppThemeChoice.dark => DealGoColors.subtlePurple,
                  },
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  switch (choice) {
                    AppThemeChoice.system => DealGoIcons.devices,
                    AppThemeChoice.light => DealGoIcons.sun,
                    AppThemeChoice.dark => DealGoIcons.moon,
                  },
                  size: 18,
                  color: switch (choice) {
                    AppThemeChoice.system => DealGoColors.primary,
                    AppThemeChoice.light => DealGoColors.amber,
                    AppThemeChoice.dark => DealGoColors.primary,
                  },
                ),
              ),
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
    this.leading,
  });

  final Key optionKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: optionKey,
      leading: leading,
      title: Text(label),
      trailing: selected
          ? const Icon(DealGoIcons.check, color: DealGoColors.primary)
          : null,
      onTap: onTap,
    );
  }
}
