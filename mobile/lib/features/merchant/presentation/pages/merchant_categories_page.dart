import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_dialog.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
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
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final ok = await showDealGoDialog<bool>(
      context: context,
      title: existing == null ? l10n.merchantCategoriesAdd : l10n.actionSave,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DealGoTextField(
            label: l10n.merchantCategoryName,
            fieldKey: const Key('merchant-category-name'),
            controller: nameCtrl,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoTextField(
            label: l10n.merchantCategoryDesc,
            controller: descCtrl,
          ),
        ],
      ),
      primaryLabel: l10n.actionSave,
      secondaryLabel: l10n.actionCancel,
      primaryKey: const Key('merchant-category-save'),
    );
    final name = nameCtrl.text.trim();
    final desc = descCtrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      descCtrl.dispose();
    });
    if (ok != true || !mounted || name.isEmpty) return;
    final token = merchantAccessToken(context) ?? '';
    final repo = context.read<MerchantOrdersRepository>();
    try {
      if (existing == null) {
        await repo.createMenuCategory(
          accessToken: token,
          name: name,
          description: desc.isEmpty ? null : desc,
        );
      } else {
        await repo.updateMenuCategory(
          accessToken: token,
          categoryId: existing.id,
          name: name,
          description: desc.isEmpty ? null : desc,
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
      title: l10n.merchantCategoriesTitle,
      onBack: () => merchantBack(context),
      footer: Padding(
        padding: merchantPagePadding,
        child: FilledButton(
          key: const Key('merchant-category-add'),
          onPressed: _loading || _reordering ? null : () => _upsert(),
          child: Text(l10n.merchantCategoriesAdd),
        ),
      ),
      body: _loading && _items.isEmpty
          ? const DealGoSkeletonList(itemCount: 4)
          : _failure != null && _items.isEmpty
          ? DealGoStateView.failure(
              context,
              onRetry: _load,
              cause: _failure,
              message: _failure is ApiException
                  ? apiErrorText(
                      AppLocalizations.of(context),
                      _failure as ApiException,
                    )
                  : null,
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
                        l10n.merchantCategoriesHeadline,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(l10n.merchantCategoriesCount('${_items.length}')),
                      DealGoTextField(
                        label: l10n.merchantCategoriesSearchHint,
                        showLabel: false,
                        hint: l10n.merchantCategoriesSearchHint,
                        prefixIcon: DealGoIcons.search,
                        controller: _search,
                        fieldKey: const Key('merchant-category-search'),
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
                  child: _items.isEmpty
                      ? DealGoStateView(
                          art: DealGoStateArt.noSearch,
                          title: l10n.merchantCategoriesEmpty,
                          compact: true,
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
                                    child: const Icon(Icons.drag_handle),
                                  ),
                                  title: Text(cat.name),
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
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: _reordering
                                            ? null
                                            : () => _upsert(existing: cat),
                                      ),
                                      IconButton(
                                        key: Key(
                                          'merchant-category-delete-${cat.id}',
                                        ),
                                        icon: const Icon(Icons.delete_outline),
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
              ],
            ),
    );
  }
}
