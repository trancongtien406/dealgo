import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_bottom_bar.dart';
import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_dialog.dart';
import '../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_refresh.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../address_book/domain/entities/saved_address.dart';
import '../../address_book/domain/repositories/address_book_repository.dart';
import '../../address_book/presentation/cubit/saved_addresses_cubit.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../places/presentation/place_lists_store.dart';
import 'account_widgets.dart';
import 'address_form_sheet.dart';

class SavedAddressesPage extends StatelessWidget {
  const SavedAddressesPage({required this.shellPath, super.key});

  final String shellPath;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final auth = context.read<AuthCubit>();
        return SavedAddressesCubit(
          repository: context.read<AddressBookRepository>(),
          accessToken: () {
            final state = auth.state;
            return state is AuthSignedIn ? state.tokens.accessToken : null;
          },
        )..load();
      },
      child: const _SavedAddressesView(),
    );
  }
}

class _SavedAddressesView extends StatelessWidget {
  const _SavedAddressesView();

  Future<void> _openForm(BuildContext context, {SavedAddress? editing}) async {
    final cubit = context.read<SavedAddressesCubit>();
    final current = cubit.state;
    final taken = {
      if (current is SavedAddressesLoaded)
        for (final address in current.items)
          if (address.id != editing?.id) address.kind,
    };
    final saved = await showAddressFormSheet(
      context,
      editing: editing,
      takenKinds: taken,
      onSubmit: (draft) => cubit.save(draft, id: editing?.id),
    );
    if (saved == true && context.mounted) {
      _publishSaved(context, cubit);
      _toast(context, AppLocalizations.of(context).addrBookSaved);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SavedAddress address,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SavedAddressesCubit>();
    final ok = await showDealGoConfirmDialog(
      context: context,
      title: l10n.addrBookDeleteTitle,
      body: l10n.addrBookDeleteBody(address.label),
      confirmLabel: l10n.addrBookDelete,
      cancelLabel: l10n.addrBookCancel,
      confirmTone: DealGoDialogPrimaryTone.danger,
      confirmKey: const Key('address-delete-confirm'),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    final error = await cubit.remove(address.id);
    if (context.mounted) {
      if (error == null) {
        _publishSaved(context, cubit);
      }
      _toast(
        context,
        error == null ? l10n.addrBookDeleted : addressErrorText(l10n, error),
      );
    }
  }

  Future<void> _makeDefault(BuildContext context, SavedAddress address) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SavedAddressesCubit>();
    final error = await cubit.makeDefault(address.id);
    if (context.mounted) {
      if (error == null) {
        _publishSaved(context, cubit);
      } else {
        _toast(context, addressErrorText(l10n, error));
      }
    }
  }

  void _publishSaved(BuildContext context, SavedAddressesCubit cubit) {
    final state = cubit.state;
    if (state is SavedAddressesLoaded) {
      context.read<PlaceListsStore>().adoptSavedAddresses(state.items);
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SavedAddressesCubit>().state;
    final full = state is SavedAddressesLoaded && state.isFull;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(title: l10n.addrBookTitle),
            Expanded(
              child: Builder(
                builder: (bodyContext) => _body(bodyContext, state),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DealGoBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (full) ...[
              Text(
                l10n.addrBookFull,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: DealGoSpacing.s8),
            ],
            DealGoPrimaryButton(
              key: const Key('address-add'),
              label: l10n.addrBookAdd,
              leadingIcon: DealGoIcons.add,
              enabled: state is SavedAddressesLoaded && !full,
              onPressed: () => _openForm(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SavedAddressesState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SavedAddressesCubit>();
    final padding = dealGoScrollPadding(
      context,
      const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
    );
    return switch (state) {
      SavedAddressesLoading() => DealGoSkeletonList(
        padding: padding,
        thumbSize: 44,
        semanticLabel: l10n.addrBookLoading,
      ),
      SavedAddressesFailed(:final cause) => DealGoRefresh(
        onRefresh: cubit.load,
        child: ListView(
          padding: padding,
          children: [
            DealGoStateView.failure(
              context,
              onRetry: cubit.load,
              cause: cause,
              compact: true,
            ),
          ],
        ),
      ),
      SavedAddressesLoaded(:final items) => DealGoRefresh(
        onRefresh: cubit.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: [
            if (items.isEmpty)
              DealGoStateView(
                art: DealGoStateArt.noAddresses,
                title: l10n.addrBookEmptyTitle,
                message: l10n.addrBookEmptyBody,
                compact: true,
              )
            else ...[
              for (final address in items) ...[
                _AddressCard(
                  address: address,
                  onEdit: () => _openForm(context, editing: address),
                  onDelete: () => _confirmDelete(context, address),
                  onMakeDefault: () => _makeDefault(context, address),
                ),
                const SizedBox(height: DealGoSpacing.s12),
              ],
            ],
          ],
        ),
      ),
    };
  }
}

enum _CardAction { edit, makeDefault, delete }

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final SavedAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final tone = switch (address.kind) {
      SavedAddressKind.home => (
        DealGoIcons.home,
        DealGoColors.subtlePurple,
        DealGoColors.primary,
      ),
      SavedAddressKind.work => (
        DealGoIcons.work,
        DealGoColors.amberSurface,
        DealGoColors.amber,
      ),
      SavedAddressKind.other => (
        DealGoIcons.pin,
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
    };
    final note = address.note;
    return DealGoCard(
      key: Key('saved-address-${address.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountToneIcon(
            icon: tone.$1,
            background: tone.$2,
            foreground: tone.$3,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: DealGoSpacing.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      address.label,
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    if (address.isDefault)
                      _DefaultBadge(label: l10n.addrBookDefault),
                  ],
                ),
                const SizedBox(height: 2),
                Text(address.addressLine, style: textTheme.bodyMedium),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note, style: textTheme.bodySmall),
                ],
                if (!address.hasPin) ...[
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    l10n.addrBookNoPin,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.amber,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<_CardAction>(
            key: Key('address-menu-${address.id}'),
            tooltip: l10n.addrBookMore,
            icon: Icon(DealGoIcons.more, color: DealGoColors.textSecondary),
            onSelected: (action) => switch (action) {
              _CardAction.edit => onEdit(),
              _CardAction.makeDefault => onMakeDefault(),
              _CardAction.delete => onDelete(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _CardAction.edit,
                child: Text(l10n.addrBookEdit),
              ),
              if (!address.isDefault)
                PopupMenuItem(
                  value: _CardAction.makeDefault,
                  child: Text(l10n.addrBookMakeDefault),
                ),
              PopupMenuItem(
                value: _CardAction.delete,
                child: Text(
                  l10n.addrBookDelete,
                  style: const TextStyle(color: DealGoColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.greenSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: 2,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: DealGoColors.brandGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String addressErrorText(AppLocalizations l10n, String code) => switch (code) {
  'ADDRESS_KIND_TAKEN' => l10n.addrBookErrKindTaken,
  'ADDRESS_LIMIT_REACHED' => l10n.addrBookFull,
  'ADDRESS_NOT_FOUND' => l10n.addrBookErrNotFound,
  'NETWORK_ERROR' => l10n.addrBookErrOffline,
  _ => l10n.addrBookErrGeneric,
};
