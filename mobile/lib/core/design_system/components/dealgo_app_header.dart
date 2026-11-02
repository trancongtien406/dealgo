import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';

/// Shared detail header: optional back · title · optional actions.
class DealGoAppHeader extends StatelessWidget implements PreferredSizeWidget {
  const DealGoAppHeader({
    this.title,
    this.subtitle,
    this.onBack,
    this.actions,
    this.trailing,
    this.showBack = true,
    this.backgroundColor,
    this.centerTitle = false,
    this.applySafeArea = false,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;

  /// Icon buttons / text actions at the end of the row.
  final Widget? actions;

  /// Optional end widget (chips, mark-all, etc.).
  final Widget? trailing;
  final bool showBack;
  final Color? backgroundColor;
  final bool centerTitle;

  /// True for `Scaffold.appBar` / map overlays. Leave false under outer SafeArea.
  final bool applySafeArea;

  @override
  Size get preferredSize =>
      const Size.fromHeight(DealGoDimensions.headerHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.maybeOf(context);
    final canPop = onBack != null || (navigator?.canPop() ?? false);
    final showBackButton = showBack && canPop;
    final textTheme = Theme.of(context).textTheme;

    final row = SizedBox(
      height: DealGoDimensions.headerHeight,
      child: Padding(
        padding: EdgeInsets.only(
          left: showBackButton ? DealGoSpacing.s4 : DealGoDimensions.pageGutter,
          right: DealGoSpacing.s8,
        ),
        child: Row(
          children: [
            if (showBackButton)
              SizedBox(
                width: DealGoDimensions.minTapTarget,
                child: IconButton(
                  key: const Key('header-back'),
                  tooltip: l10n.actionBack,
                  onPressed: onBack ?? () => navigator?.maybePop(),
                  icon: const Icon(DealGoIcons.back, size: 24),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      header: true,
                      // Fixed-height header: cap scaling so title + subtitle
                      // fit at accessibility text sizes.
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: kHeaderMaxTextScale,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: centerTitle
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: centerTitle
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            ?actions,
            ?trailing,
          ],
        ),
      ),
    );

    return Material(
      color: backgroundColor ?? DealGoColors.card,
      child: applySafeArea ? SafeArea(bottom: false, child: row) : row,
    );
  }
}

/// Max text scale inside [DealGoAppHeader]'s fixed-height title block.
const double kHeaderMaxTextScale = 1.2;
