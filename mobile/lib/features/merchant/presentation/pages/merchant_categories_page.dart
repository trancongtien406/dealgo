import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/format/text_case.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/merchant_menu_models.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../widgets/merchant_widgets.dart';

/// M025 — merchant menu category CRUD + drag reorder (DEC-PROD-039/040).
class MerchantCategoriesPage extends StatefulWidget {
  const MerchantCategoriesPage({super.key});

  @override
  State<MerchantCategoriesPage> createState() => _MerchantCategoriesPageState();
}

class _MerchantCategoriesPageState extends State<MerchantCategoriesPage> {
  var _loading = true;
  var _reordering = false;
  Object? _failure;
  List<MerchantMenuCategory> _items = const [];
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<MerchantMenuCategory> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return [
      for (final c in _items)
        if (c.name.toLowerCase().contains(q)) c,
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final items = await context
          .read<MerchantOrdersRepository>()
          .listMenuCategories(merchantAccessToken(context) ?? '');
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = error;
        });
      }
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    // onReorderItem already adjusts newIndex for the removed item.
    if (_reordering || oldIndex == newIndex) return;
    var next = List<MerchantMenuCategory>.of(_items);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    setState(() {
      _items = next;
      _reordering = true;
    });
    try {
      final saved = await context
          .read<MerchantOrdersRepository>()
          .reorderMenuCategories(
            accessToken: merchantAccessToken(context) ?? '',
            orderedIds: [for (final c in next) c.id],
          );
      if (!mounted) return;
      setState(() {
        _items = saved;
        _reordering = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).merchantCategoriesReordered,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _reordering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorText(AppLocalizations.of(context), e))),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _reordering = false);
        await _load();
      }
    }
  }

  Future<void> _upsert({MerchantMenuCategory? existing}) async {
    final l10n = AppLocalizations.of(context);
    final draft = await showDealGoSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryUpsertSheet(existing: existing),
    );
    if (draft == null || !mounted) return;
    final (name, desc) = draft;
    if (name.isEmpty) return;
    final token = merchantAccessToken(context) ?? '';
    final repo = context.read<MerchantOrdersRepository>();
    try {
      if (existing == null) {
        await repo.createMenuCategory(
          accessToken: token,
          name: name,
          description: desc,
        );
      } else {
        await repo.updateMenuCategory(
          accessToken: token,
          categoryId: existing.id,
          name: name,
          description: desc,
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorText(l10n, e))));
      }
    }
  }

  Future<void> _delete(MerchantMenuCategory cat) async {
    try {
      await context.read<MerchantOrdersRepository>().deleteMenuCategory(
        accessToken: merchantAccessToken(context) ?? '',
        categoryId: cat.id,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorText(AppLocalizations.of(context), e)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MerchantPageFrame(
      title: l10n.merchantCategoriesHeadline,
      onBack: () => merchantBack(context),
      footer: MerchantPrimaryBar(
        label: l10n.merchantCategoriesAdd,
        buttonKey: const Key('merchant-category-add'),
        enabled: !_loading && !_reordering,
        onPressed: () => _upsert(),
      ),
      body: _loading && _items.isEmpty
          ? const DealGoSkeletonList(itemCount: 4)
          : _failure != null && _items.isEmpty
          ? DealGoRefresh(
              onRefresh: _load,
              child: DealGoStateView.failure(
                context,
                onRetry: _load,
                cause: _failure,
                message: _failure is ApiException
                    ? apiErrorText(
                        AppLocalizations.of(context),
                        _failure as ApiException,
                      )
                    : null,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: merchantPagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.merchantCategoriesCount('${_items.length}'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      DealGoTextField(
                        label: l10n.merchantCategoriesSearchHint,
                        showLabel: false,
                        hint: l10n.merchantCategoriesSearchHint,
                        prefixIcon: DealGoIcons.search,
                        controller: _search,
                        fieldKey: const Key('merchant-category-search'),
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_failure != null)
                        Text(
                          _failure is ApiException
                              ? apiErrorText(l10n, _failure as ApiException)
                              : l10n.errorLoadFailed,
                          style: const TextStyle(color: DealGoColors.danger),
                        ),
                      if (_reordering)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: DealGoRefresh(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? DealGoStateView(
                            art: DealGoStateArt.noSearch,
                            title: l10n.merchantCategoriesEmpty,
                          )
                        : ReorderableListView.builder(
                            key: const Key('merchant-category-reorder'),
                            padding: merchantPagePadding,
                            itemCount: _visible.length,
                            buildDefaultDragHandles: false,
                            onReorderItem: _search.text.trim().isEmpty
                                ? _reorder
                                : (oldIndex, newIndex) {},
                            itemBuilder: (context, index) {
                              final cat = _visible[index];
                              return MerchantPanel(
                                key: Key('merchant-category-${cat.id}'),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    leading: ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(DealGoIcons.dragHandle),
                                    ),
                                    title: Text(
                                      capitalizeFirstLetter(cat.name),
                                    ),
                                    subtitle: Text(
                                      l10n.merchantCategoriesItemsOnSale(
                                        '${cat.itemCount}',
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          key: Key(
                                            'merchant-category-edit-${cat.id}',
                                          ),
                                          icon: const Icon(DealGoIcons.edit),
                                          onPressed: _reordering
                                              ? null
                                              : () => _upsert(existing: cat),
                                        ),
                                        IconButton(
                                          key: Key(
                                            'merchant-category-delete-${cat.id}',
                                          ),
                                          icon: const Icon(DealGoIcons.trash),
                                          onPressed: _reordering
                                              ? null
                                              : () => _delete(cat),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryUpsertSheet extends StatefulWidget {
  const _CategoryUpsertSheet({this.existing});

  final MerchantMenuCategory? existing;

  @override
  State<_CategoryUpsertSheet> createState() => _CategoryUpsertSheetState();
}

class _CategoryUpsertSheetState extends State<_CategoryUpsertSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s20,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? l10n.merchantCategoriesAdd
                  : l10n.actionSave,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              label: l10n.merchantCategoryName,
              fieldKey: const Key('merchant-category-name'),
              controller: _name,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              label: l10n.merchantCategoryDesc,
              controller: _desc,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: DealGoSpacing.s20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: l10n.actionCancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoPrimaryButton(
                      key: const Key('merchant-category-save'),
                      label: l10n.actionSave,
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        final name = _name.text.trim();
                        final desc = _desc.text.trim();
                        Navigator.of(context).pop((
                          name,
                          desc.isEmpty ? null : desc,
                        ));
                      },
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
