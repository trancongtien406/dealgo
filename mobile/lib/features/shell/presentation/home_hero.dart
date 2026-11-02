import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../inbox/presentation/inbox_unread.dart';

import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/presentation/widgets/auth_widgets.dart';
import '../../food/presentation/utils/food_routes.dart';
import '../../places/presentation/place_picker_page.dart';
import '../../ride/presentation/cubit/ride_destination.dart';
import 'account_routes.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DealGoWordmark(),
              Text(
                AppLocalizations.of(context).homeTagline,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const _LocationChip(),
        const SizedBox(width: DealGoSpacing.s8),
        const _Bell(),
        const SizedBox(width: DealGoSpacing.s8),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip();

  Future<void> _pick(BuildContext context) async {
    final place = await pickPlace(context, PlacePickPurpose.pickup);
    if (place == null || !context.mounted) {
      return;
    }
    context.read<RideDestinationCubit>().choose(place);
    context.go('/customer/book');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: DealGoColors.card,
      shape: StadiumBorder(side: BorderSide(color: DealGoColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Semantics(
          button: true,
          label: l10n.homeCitySample,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s8,
              vertical: DealGoSpacing.s8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  DealGoIcons.pinFilled,
                  color: DealGoColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  l10n.homeCitySample,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: DealGoColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  DealGoIcons.expandMore,
                  size: 16,
                  color: DealGoColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bell extends StatefulWidget {
  const _Bell();

  @override
  State<_Bell> createState() => _BellState();
}

class _BellState extends State<_Bell> {
  @override
  void initState() {
    super.initState();
    attachInboxUnread(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: DealGoColors.card,
            shape: CircleBorder(side: BorderSide(color: DealGoColors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(
                AccountRoutes.notifications('/customer/account'),
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  DealGoIcons.notifications,
                  color: DealGoColors.text,
                  size: 20,
                  semanticLabel: l10n.accountNotifications,
                ),
              ),
            ),
          ),
          // Dot only while the inbox really has unread items.
          Positioned(
            right: 6,
            top: 6,
            child: ListenableBuilder(
              listenable: InboxUnread.instance,
              builder: (context, _) => InboxUnread.instance.count > 0
                  ? DecoratedBox(
                      key: const Key('home-bell-unread'),
                      decoration: BoxDecoration(
                        color: DealGoColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DealGoColors.card,
                          width: 1.5,
                        ),
                      ),
                      child: const SizedBox(width: 8, height: 8),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// C001 search: one field for destinations and food. Submitting asks which
/// kind of search to run (DEC-PROD-030) instead of guessing.
class HomeSearch extends StatefulWidget {
  const HomeSearch({required this.onBook, super.key});

  /// Opens ride booking once a destination is chosen.
  final VoidCallback onBook;

  @override
  State<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<HomeSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<_HomeSearchKind>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s16,
              ),
              child: Text(
                l10n.homeSearchChooseTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const Key('home-search-food'),
              leading: const Icon(
                DealGoIcons.food,
                color: DealGoColors.primary,
              ),
              title: Text(l10n.homeSearchAsFood(query)),
              onTap: () => Navigator.of(sheetContext).pop(_HomeSearchKind.food),
            ),
            ListTile(
              key: const Key('home-search-place'),
              leading: const Icon(
                DealGoIcons.pinFilled,
                color: DealGoColors.brandGreen,
              ),
              title: Text(l10n.homeSearchAsPlace(query)),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_HomeSearchKind.place),
            ),
            const SizedBox(height: DealGoSpacing.s8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case _HomeSearchKind.food:
        await context.push(FoodRoutes.searchFor(query));
      case _HomeSearchKind.place:
        final destination = context.read<RideDestinationCubit>();
        final place = await pickPlace(
          context,
          PlacePickPurpose.dropoff,
          initialQuery: query,
        );
        if (place == null || !mounted) {
          return;
        }
        destination.choose(place);
        widget.onBook();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoTextField(
      label: l10n.homeSearchHint,
      showLabel: false,
      hint: l10n.homeSearchHint,
      prefixIcon: DealGoIcons.search,
      controller: _controller,
      fieldKey: const Key('home-search-field'),
      textInputAction: TextInputAction.search,
      onSubmitted: _submit,
      suffix: IconButton(
        onPressed: widget.onBook,
        tooltip: l10n.tabBook,
        icon: Icon(
          DealGoIcons.scan,
          color: DealGoColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

enum _HomeSearchKind { food, place }

/// C001 hero carousel. Auto-advances unless the user prefers reduced motion.
