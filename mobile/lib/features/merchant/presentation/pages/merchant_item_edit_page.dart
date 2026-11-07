import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/drafts/text_draft.dart';
import '../../../../core/format/text_case.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../onboarding/presentation/document_image_source.dart';
import '../../domain/entities/merchant_menu_models.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../cubit/merchant_item_options_cubit.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';

const int _maxMenuItemImages = 4;

/// M027 — unified create & edit form for a store dish (DEC-PROD-039, DEC-PROD-042).
/// All fields, including staged gallery photos and option groups, are submitted
/// together in the form save request.
class MerchantItemEditPage extends StatefulWidget {
  const MerchantItemEditPage({super.key, this.itemId, this.initial});

  /// Null or empty when creating a new dish.
  final String? itemId;
  final FoodMenuItem? initial;

  bool get isCreate => itemId == null || itemId!.trim().isEmpty;

  @override
  State<MerchantItemEditPage> createState() => _MerchantItemEditPageState();
}

class _MerchantItemEditPageState extends State<MerchantItemEditPage>
    with TextDraftMixin {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _originalPrice = TextEditingController();
  final _description = TextEditingController();
  final _prep = TextEditingController();

  int? _loadedOriginalPrice;
  String? _loadedDescription;
  int? _loadedPrepMinutes;
  String? _loadedCategoryId;
  List<String> _loadedImageUrls = const [];

  var _available = true;
  FoodItemModeration _moderation = FoodItemModeration.approved;
  String? _categoryId;
  var _loading = true;
  var _formReady = false;
  var _missing = false;
  Object? _loadFailure;
  var _busy = false;
  String? _error;

  /// Existing server image URLs kept in the form.
  List<String> _existingImageUrls = const [];

  /// Newly picked photos staged in memory; uploaded when saving the form.
  List<PickedDocumentImage> _pendingPhotos = const [];

  /// Option groups configured on this dish.
  List<FoodOptionGroup> _optionGroups = const [];
  var _optionGroupsDirty = false;

  int _soldCount = 0;
  List<MerchantMenuCategory> _categories = const [];

  int get _totalPhotos => _existingImageUrls.length + _pendingPhotos.length;

  bool get _photosChanged {
    if (_pendingPhotos.isNotEmpty) return true;
    if (_existingImageUrls.length != _loadedImageUrls.length) return true;
    for (var i = 0; i < _existingImageUrls.length; i++) {
      if (_existingImageUrls[i] != _loadedImageUrls[i]) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _price.addListener(_onFieldChanged);
    _originalPrice.addListener(_onFieldChanged);
    _prep.addListener(_onFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _price.removeListener(_onFieldChanged);
    _originalPrice.removeListener(_onFieldChanged);
    _prep.removeListener(_onFieldChanged);
    _name.dispose();
    _price.dispose();
    _originalPrice.dispose();
    _description.dispose();
    _prep.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = merchantAccessToken(context) ?? '';
    final repo = context.read<MerchantOrdersRepository>();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _loadFailure = sessionExpiredFailure;
      });
      return;
    }
    try {
      final cats = await repo.listMenuCategories(token);
      if (widget.isCreate) {
        if (!mounted) return;
        setState(() {
          _categories = cats;
          _loading = false;
          _formReady = true;
          _loadFailure = null;
          _missing = false;
        });
        bindTextDraft('merchant.item._new', {
          'name': _name,
          'price': _price,
          'originalPrice': _originalPrice,
          'description': _description,
          'prep': _prep,
        });
        return;
      }

      final targetId = widget.itemId!;
      FoodMenuItem? item = widget.initial;
      if (item == null || item.id != targetId) {
        final store = await repo.getMerchantCatalog(token);
        for (final row in store.items) {
          if (row.id == targetId) {
            item = row;
            break;
          }
        }
      }
      if (!mounted) return;
      if (item == null) {
        setState(() {
          _loading = false;
          _missing = true;
        });
        return;
      }
      _name.text = item.name;
      _price.text = '${item.priceVnd}';
      _loadedOriginalPrice = item.originalPriceVnd;
      _originalPrice.text = item.originalPriceVnd?.toString() ?? '';
      _loadedDescription = item.description;
      _description.text = item.description ?? '';
      _loadedPrepMinutes = item.prepMinutes;
      _prep.text = item.prepMinutes?.toString() ?? '';
      _available = item.available;
      _moderation = item.moderation;
      _loadedCategoryId = item.menuCategoryId;
      _categoryId = item.menuCategoryId;
      final urls = item.imageUrls.isNotEmpty
          ? List<String>.of(item.imageUrls)
          : (item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? <String>[item.imageUrl!]
                : <String>[]);
      _loadedImageUrls = List.unmodifiable(urls);
      _existingImageUrls = List<String>.of(urls);
      _pendingPhotos = const [];
      _optionGroups = List<FoodOptionGroup>.of(item.optionGroups);
      _optionGroupsDirty = false;
      _soldCount = item.soldCount;
      setState(() {
        _categories = cats;
        _loading = false;
        _formReady = true;
        _loadFailure = null;
        _missing = false;
      });
      // Unsaved edits of this item survive an app kill (text fields only).
      bindTextDraft('merchant.item.$targetId', {
        'name': _name,
        'price': _price,
        'originalPrice': _originalPrice,
        'description': _description,
        'prep': _prep,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailure = e;
      });
    }
  }

  Future<void> _pickPhoto({bool camera = false}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    if (_totalPhotos >= _maxMenuItemImages) {
      setState(() {
        _error = l10n.merchantItemPhotoLimitError(_maxMenuItemImages);
      });
      return;
    }
    final source = context.read<DocumentImageSource>();
    final picked = await source.pick(camera: camera);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingPhotos = [..._pendingPhotos, picked];
      _error = null;
    });
  }

  void _removeExistingPhotoAt(int index) {
    if (_busy || index < 0 || index >= _existingImageUrls.length) return;
    setState(() {
      final next = List<String>.of(_existingImageUrls)..removeAt(index);
      _existingImageUrls = next;
      _error = null;
    });
  }

  void _removePendingPhotoAt(int index) {
    if (_busy || index < 0 || index >= _pendingPhotos.length) return;
    setState(() {
      final next = List<PickedDocumentImage>.of(_pendingPhotos)
        ..removeAt(index);
      _pendingPhotos = next;
      _error = null;
    });
  }

  void _makeExistingCover(int index) {
    if (_busy || index <= 0 || index >= _existingImageUrls.length) return;
    setState(() {
      final next = List<String>.of(_existingImageUrls);
      final chosen = next.removeAt(index);
      next.insert(0, chosen);
      _existingImageUrls = next;
    });
  }

  void _clearAllPhotos() {
    if (_busy || _totalPhotos == 0) return;
    setState(() {
      _existingImageUrls = const [];
      _pendingPhotos = const [];
      _error = null;
    });
  }

  Future<void> _quickCreateCategory() async {
    if (_busy) return;
    final createdName = await showDealGoSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QuickCreateCategorySheet(),
    );
    if (createdName == null || createdName.isEmpty || !mounted) return;
    try {
      final cat = await context
          .read<MerchantOrdersRepository>()
          .createMenuCategory(
            accessToken: merchantAccessToken(context) ?? '',
            name: createdName,
          );
      if (!mounted) return;
      setState(() {
        _categories = [..._categories, cat];
        _categoryId = cat.id;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorText(AppLocalizations.of(context), e));
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    if (_busy || widget.isCreate) return;
    final l10n = AppLocalizations.of(context);
    final itemName = _name.text.trim().isEmpty
        ? (widget.initial?.name ?? '')
        : _name.text.trim();
    final confirmed = await showDealGoSheet<bool>(
      context: context,
      builder: (sheetContext) {
        final sheetL10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s20,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sheetL10n.merchantItemDeleteConfirmTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  sheetL10n.merchantItemDeleteConfirmBody(itemName),
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s20),
                Row(
                  children: [
                    Expanded(
                      child: DealGoSecondaryButton(
                        label: sheetL10n.actionCancel,
                        compact: true,
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: DealGoSecondaryButton(
                        key: const Key('merchant-edit-delete-confirm'),
                        label: sheetL10n.merchantItemDeleteAction,
                        compact: true,
                        tone: DealGoSecondaryTone.danger,
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<MerchantOrdersRepository>().deleteCatalogItem(
        accessToken: merchantAccessToken(context) ?? '',
        itemId: widget.itemId!,
      );
      clearTextDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.merchantItemDeleted)));
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorText(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({required bool continueToVariants}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    final prepText = _prep.text.trim();
    final prep = prepText.isEmpty ? null : int.tryParse(prepText);
    if (name.isEmpty || price == null || price < 1) {
      setState(() => _error = l10n.merchantItemInvalid);
      return;
    }
    if (prepText.isNotEmpty && (prep == null || prep < 1 || prep > 240)) {
      setState(() => _error = l10n.merchantItemInvalid);
      return;
    }
    final originalText = _originalPrice.text.trim();
    final original = originalText.isEmpty ? null : int.tryParse(originalText);
    if (originalText.isNotEmpty && (original == null || original <= price)) {
      setState(() => _error = l10n.merchantItemOriginalPriceInvalid);
      return;
    }
    final descriptionText = _description.text.trim();
    final description = descriptionText.isEmpty ? null : descriptionText;

    final stagedUploads = [
      for (final photo in _pendingPhotos)
        MerchantItemImageUpload(
          contentBase64: base64Encode(photo.bytes),
          contentType: photo.contentType,
        ),
    ];

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = context.read<MerchantOrdersRepository>();
      final token = merchantAccessToken(context) ?? '';
      final FoodMenuItem saved;
      if (widget.isCreate) {
        saved = await repo.createCatalogItem(
          accessToken: token,
          name: name,
          priceVnd: price,
          available: _available,
          description: description,
          prepMinutes: prep,
          menuCategoryId: _categoryId,
          originalPriceVnd: original,
          newImages: stagedUploads.isNotEmpty ? stagedUploads : null,
          optionGroups: _optionGroups.isNotEmpty ? _optionGroups : null,
        );
      } else {
        saved = await repo.updateCatalogItem(
          accessToken: token,
          itemId: widget.itemId!,
          name: name,
          priceVnd: price,
          available: _available,
          description: description,
          clearDescription: description == null && _loadedDescription != null,
          prepMinutes: prep,
          clearPrepMinutes: prep == null && _loadedPrepMinutes != null,
          menuCategoryId: _categoryId,
          clearMenuCategoryId: _categoryId == null && _loadedCategoryId != null,
          originalPriceVnd: original,
          clearOriginalPrice: original == null && _loadedOriginalPrice != null,
          imageUrls: _photosChanged ? _existingImageUrls : null,
          newImages: stagedUploads.isNotEmpty ? stagedUploads : null,
          optionGroups: _optionGroupsDirty ? _optionGroups : null,
        );
      }
      clearTextDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.merchantItemSaved)));
      if (continueToVariants) {
        context.push(MerchantRoutes.itemVariants(saved.id, itemName: name));
      } else {
        context.pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorText(AppLocalizations.of(context), e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.merchantItemUpdateFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOrEditOptionGroup({int? index}) async {
    if (_busy) return;
    final existing = index != null ? _optionGroups[index] : null;
    final result = await showDealGoSheet<FoodOptionGroup?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InlineOptionGroupSheet(group: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      final next = List<FoodOptionGroup>.of(_optionGroups);
      if (result.title.isEmpty) {
        if (index != null) next.removeAt(index);
      } else if (index != null) {
        next[index] = result;
      } else {
        next.add(result);
      }
      _optionGroups = next;
      _optionGroupsDirty = true;
    });
  }

  String _groupRule(AppLocalizations l10n, FoodOptionGroup group) {
    if (group.minSelect == 0) {
      return group.maxSelect <= 1
          ? l10n.merchantOptionsRuleOptionalOne
          : l10n.merchantOptionsRuleUpTo(group.maxSelect);
    }
    if (group.minSelect == 1 && group.maxSelect == 1) {
      return l10n.merchantOptionsRuleRequiredOne;
    }
    return l10n.merchantOptionsRuleRange(group.minSelect, group.maxSelect);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final priceVal = int.tryParse(_price.text.trim());
    final selectedCat = _categories.cast<MerchantMenuCategory?>().firstWhere(
      (c) => c?.id == _categoryId,
      orElse: () => null,
    );

    return MerchantPageFrame(
      title: widget.isCreate ? l10n.merchantAddItem : l10n.merchantItemEditTitle,
      onBack: () => merchantBack(context),
      trailing: !widget.isCreate && _formReady
          ? IconButton(
              key: const Key('merchant-edit-delete-header'),
              tooltip: l10n.merchantItemDeleteAction,
              icon: const Icon(
                DealGoIcons.trash,
                color: DealGoColors.danger,
                size: 20,
              ),
              onPressed: _busy ? null : _confirmAndDelete,
            )
          : null,
      footer: !_loading && _formReady
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DealGoSecondaryButton(
                        key: const Key('merchant-edit-continue-variants'),
                        label: l10n.merchantItemContinue,
                        compact: true,
                        enabled: !_busy,
                        onPressed: () => _save(continueToVariants: true),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    Expanded(
                      child: DealGoPrimaryButton(
                        key: const Key('merchant-edit-save'),
                        label: l10n.actionSave,
                        compact: true,
                        isLoading: _busy,
                        onPressed: () => _save(continueToVariants: false),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _loading
          ? const DealGoSkeletonList(itemCount: 4)
          : !_formReady
          ? (_missing
                ? DealGoStateView(
                    art: DealGoStateArt.noSearch,
                    title: l10n.merchantOptionsItemMissing,
                    compact: true,
                  )
                : DealGoStateView.failure(
                    context,
                    onRetry: _bootstrap,
                    cause: _loadFailure,
                    message: _loadFailure is ApiException
                        ? apiErrorText(l10n, _loadFailure)
                        : l10n.merchantItemUpdateFailed,
                  ))
          : SingleChildScrollView(
              padding: dealGoScrollPadding(context, merchantPagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _available
                              ? l10n.merchantEditStatusOnSale
                              : l10n.merchantEditStatusHidden,
                          key: const Key('merchant-edit-status'),
                          style: textTheme.labelLarge?.copyWith(
                            color: _available
                                ? DealGoColors.brandGreen
                                : DealGoColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!widget.isCreate && _soldCount > 0) ...[
                        Text(
                          l10n.merchantProductsSoldCount('$_soldCount'),
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s8),
                      ],
                      if (!widget.isCreate)
                        DealGoChip(
                          label: switch (_moderation) {
                            FoodItemModeration.pending =>
                              l10n.merchantItemPendingReview,
                            FoodItemModeration.rejected =>
                              l10n.merchantItemRejected,
                            FoodItemModeration.approved =>
                              _available
                                  ? l10n.merchantItemOnSale
                                  : l10n.merchantItemSoldOut,
                          },
                          tone: switch (_moderation) {
                            FoodItemModeration.pending =>
                              DealGoChipTone.warning,
                            FoodItemModeration.rejected =>
                              DealGoChipTone.danger,
                            FoodItemModeration.approved =>
                              _available
                                  ? DealGoChipTone.success
                                  : DealGoChipTone.neutral,
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),

                  // Section 1: Unified Photo Gallery (upload & delete staged in form)
                  MerchantPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.merchantItemPhoto,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DealGoChip(
                              label: l10n.merchantItemPhotoCount(
                                _totalPhotos,
                                _maxMenuItemImages,
                              ),
                              tone: _totalPhotos > 0
                                  ? DealGoChipTone.brand
                                  : DealGoChipTone.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s4),
                        Text(
                          l10n.merchantItemPhotoHint,
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        SizedBox(
                          height: 104,
                          child: ListView(
                            key: const Key('merchant-edit-gallery'),
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (
                                var i = 0;
                                i < _existingImageUrls.length;
                                i++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: DealGoSpacing.s8,
                                  ),
                                  child: _GalleryPhotoTile(
                                    key: Key('merchant-edit-photo-existing-$i'),
                                    isCover: i == 0,
                                    isStagedNew: false,
                                    coverLabel: l10n.merchantItemPhotoCover,
                                    newLabel: l10n.merchantItemPhotoNew,
                                    onTap: i > 0
                                        ? () => _makeExistingCover(i)
                                        : null,
                                    onRemove: () => _removeExistingPhotoAt(i),
                                    removeKey: Key(
                                      'merchant-edit-photo-remove-$i',
                                    ),
                                    child: DealGoNetworkImage(
                                      resolveMediaUrl(_existingImageUrls[i]) ??
                                          _existingImageUrls[i],
                                      fit: BoxFit.cover,
                                      fallback: ColoredBox(
                                        color: DealGoColors.subtlePurple,
                                        child: const Icon(
                                          DealGoIcons.restaurant,
                                          color: DealGoColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              for (
                                var j = 0;
                                j < _pendingPhotos.length;
                                j++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: DealGoSpacing.s8,
                                  ),
                                  child: _GalleryPhotoTile(
                                    key: Key('merchant-edit-photo-pending-$j'),
                                    isCover:
                                        _existingImageUrls.isEmpty && j == 0,
                                    isStagedNew: true,
                                    coverLabel: l10n.merchantItemPhotoCover,
                                    newLabel: l10n.merchantItemPhotoNew,
                                    onRemove: () => _removePendingPhotoAt(j),
                                    removeKey: Key(
                                      'merchant-edit-photo-remove-${_existingImageUrls.length + j}',
                                    ),
                                    child: Image.memory(
                                      _pendingPhotos[j].bytes,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          ColoredBox(
                                            color: DealGoColors.subtlePurple,
                                            child: const Icon(
                                              DealGoIcons.image,
                                              color: DealGoColors.primary,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              if (_totalPhotos == 0)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: DealGoSpacing.s8,
                                  ),
                                  child: InkWell(
                                    onTap: _busy ? null : _pickPhoto,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        color: DealGoColors.subtlePurple,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: DealGoColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            DealGoIcons.addPhoto,
                                            color: DealGoColors.primary,
                                            size: 26,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.merchantItemPhotoEmpty,
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: DealGoColors
                                                      .textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        Wrap(
                          spacing: DealGoSpacing.s8,
                          runSpacing: DealGoSpacing.s8,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('merchant-edit-photo-pick'),
                              onPressed:
                                  _busy || _totalPhotos >= _maxMenuItemImages
                                  ? null
                                  : () => _pickPhoto(camera: false),
                              icon: const Icon(DealGoIcons.addPhoto, size: 18),
                              label: Text(l10n.merchantItemPhotoPick),
                            ),
                            OutlinedButton.icon(
                              key: const Key('merchant-edit-photo-camera'),
                              onPressed:
                                  _busy || _totalPhotos >= _maxMenuItemImages
                                  ? null
                                  : () => _pickPhoto(camera: true),
                              icon: const Icon(DealGoIcons.camera, size: 18),
                              label: Text(l10n.merchantItemPhotoCamera),
                            ),
                            if (_totalPhotos > 0)
                              TextButton.icon(
                                key: const Key('merchant-edit-photo-clear'),
                                onPressed: _busy ? null : _clearAllPhotos,
                                icon: const Icon(
                                  DealGoIcons.trash,
                                  size: 16,
                                  color: DealGoColors.danger,
                                ),
                                label: Text(
                                  l10n.merchantItemPhotoClear,
                                  style: const TextStyle(
                                    color: DealGoColors.danger,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),

                  // Section 2: Basic Information
                  MerchantPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.merchantItemInfo,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        DealGoTextField(
                          label: '${l10n.merchantItemName} *',
                          fieldKey: const Key('merchant-edit-name'),
                          controller: _name,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: InkWell(
                                key: const Key('merchant-edit-category'),
                                onTap: () async {
                                  final picked = await showCategoryPickerSheet(
                                    context: context,
                                    categories: _categories,
                                    selectedId: _categoryId,
                                  );
                                  if (picked != null) {
                                    setState(() => _categoryId = picked.$1);
                                  }
                                },
                                borderRadius: BorderRadius.circular(
                                  DealGoRadius.input,
                                ),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: l10n.merchantItemCategory,
                                    suffixIcon: const Icon(
                                      DealGoIcons.chevronDown,
                                      size: 20,
                                    ),
                                  ),
                                  child: Text(
                                    selectedCat != null
                                        ? capitalizeFirstLetter(
                                            selectedCat.name,
                                          )
                                        : '— ${l10n.merchantItemCategoryNone}',
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: selectedCat != null
                                          ? null
                                          : DealGoColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s8),
                            IconButton.outlined(
                              key: const Key('merchant-edit-category-add'),
                              tooltip: l10n.merchantItemCategoryCreateTitle,
                              onPressed: _busy ? null : _quickCreateCategory,
                              icon: const Icon(DealGoIcons.add, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        DealGoTextField(
                          label: l10n.merchantItemDescription,
                          fieldKey: const Key('merchant-edit-description'),
                          controller: _description,
                          textInputAction: TextInputAction.newline,
                          maxLines: 3,
                          maxLength: 500,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),

                  // Section 3: Pricing & Promotion
                  MerchantPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.merchantItemPricingSection,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (priceVal != null && priceVal > 0)
                              Text(
                                formatVnd(priceVal),
                                style: textTheme.titleSmall?.copyWith(
                                  color: DealGoColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DealGoTextField(
                                label: '${l10n.merchantItemPrice} *',
                                fieldKey: const Key('merchant-edit-price'),
                                controller: _price,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s12),
                            Expanded(
                              child: DealGoTextField(
                                label: l10n.merchantItemOriginalPrice,
                                fieldKey: const Key(
                                  'merchant-edit-original-price',
                                ),
                                controller: _originalPrice,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),

                  // Section 4: Prep Time & Availability
                  MerchantPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.merchantItemPrepSection,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        DealGoTextField(
                          label: l10n.merchantItemPrep,
                          fieldKey: const Key('merchant-edit-prep'),
                          controller: _prep,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Wrap(
                          spacing: DealGoSpacing.s8,
                          runSpacing: DealGoSpacing.s4,
                          children: [
                            for (final mins in const [5, 10, 15, 20, 30])
                              ChoiceChip(
                                label: Text(
                                  l10n.merchantItemPrepMinutesChip(mins),
                                ),
                                selected: _prep.text.trim() == '$mins',
                                onSelected: _busy
                                    ? null
                                    : (_) => setState(
                                        () => _prep.text = '$mins',
                                      ),
                              ),
                            if (_prep.text.trim().isNotEmpty)
                              ActionChip(
                                label: Text(l10n.merchantItemPrepClear),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _prep.clear()),
                              ),
                          ],
                        ),
                        const Divider(height: DealGoSpacing.s24),
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile.adaptive(
                            key: const Key('merchant-edit-available'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.merchantItemVisible,
                              style: textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              l10n.merchantItemVisibleBody,
                              style: textTheme.bodySmall?.copyWith(
                                color: DealGoColors.textSecondary,
                              ),
                            ),
                            value: _available,
                            onChanged: (v) => setState(() => _available = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),

                  // Section 5: Option Groups (Size / Topping) inline in form
                  MerchantPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.merchantVariantsCta,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DealGoChip(
                              label: l10n.merchantItemOptionsGroupCount(
                                _optionGroups.length,
                              ),
                              tone: _optionGroups.isNotEmpty
                                  ? DealGoChipTone.brand
                                  : DealGoChipTone.neutral,
                            ),
                          ],
                        ),
                        if (_optionGroups.isEmpty) ...[
                          const SizedBox(height: DealGoSpacing.s4),
                          Text(
                            l10n.merchantOptionsEmpty,
                            style: textTheme.bodySmall?.copyWith(
                              color: DealGoColors.textSecondary,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: DealGoSpacing.s12),
                          for (var gi = 0; gi < _optionGroups.length; gi++) ...[
                            Container(
                              margin: const EdgeInsets.only(
                                bottom: DealGoSpacing.s8,
                              ),
                              padding: const EdgeInsets.all(DealGoSpacing.s12),
                              decoration: BoxDecoration(
                                color: DealGoColors.canvas,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: DealGoColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _optionGroups[gi].title,
                                          style: textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _groupRule(l10n, _optionGroups[gi]),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: DealGoColors.textSecondary,
                                          ),
                                        ),
                                        if (_optionGroups[gi]
                                            .choices
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _optionGroups[gi].choices
                                                .map(
                                                  (c) => c.extraVnd > 0
                                                      ? '${c.label} (+${formatVnd(c.extraVnd)})'
                                                      : c.label,
                                                )
                                                .join(', '),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      DealGoIcons.edit,
                                      size: 18,
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () => _addOrEditOptionGroup(
                                            index: gi,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: DealGoSpacing.s8),
                        if (_optionGroups.length < merchantOptionMaxGroups)
                          OutlinedButton.icon(
                            key: const Key('merchant-edit-add-option-group'),
                            onPressed: _busy
                                ? null
                                : () => _addOrEditOptionGroup(),
                            icon: const Icon(DealGoIcons.add, size: 18),
                            label: Text(l10n.merchantOptionsAddGroup),
                          ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: DealGoSpacing.s16),
                    Text(
                      _error!,
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  // Section 6: Delete Dish (Edit mode)
                  if (!widget.isCreate) ...[
                    const SizedBox(height: DealGoSpacing.s20),
                    DealGoSecondaryButton(
                      key: const Key('merchant-edit-delete'),
                      label: l10n.merchantItemDeleteAction,
                      tone: DealGoSecondaryTone.danger,
                      leadingIcon: DealGoIcons.trash,
                      enabled: !_busy,
                      onPressed: _confirmAndDelete,
                    ),
                  ],
                  const SizedBox(height: DealGoSpacing.s16),
                ],
              ),
            ),
    );
  }
}

class _QuickCreateCategorySheet extends StatefulWidget {
  const _QuickCreateCategorySheet();

  @override
  State<_QuickCreateCategorySheet> createState() =>
      _QuickCreateCategorySheetState();
}

class _QuickCreateCategorySheetState extends State<_QuickCreateCategorySheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
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
              l10n.merchantItemCategoryCreateTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              label: l10n.merchantCategoryName,
              fieldKey: const Key('merchant-edit-quick-category-name'),
              controller: _name,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: DealGoSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: DealGoSecondaryButton(
                    label: l10n.actionCancel,
                    compact: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: DealGoPrimaryButton(
                    key: const Key('merchant-edit-quick-category-save'),
                    label: l10n.actionSave,
                    compact: true,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      final text = _name.text.trim();
                      if (text.isEmpty) return;
                      Navigator.of(context).pop(text);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryPhotoTile extends StatelessWidget {
  const _GalleryPhotoTile({
    required this.child,
    required this.isCover,
    required this.isStagedNew,
    required this.coverLabel,
    required this.newLabel,
    required this.onRemove,
    required this.removeKey,
    this.onTap,
    super.key,
  });

  final Widget child;
  final bool isCover;
  final bool isStagedNew;
  final String coverLabel;
  final String newLabel;
  final VoidCallback onRemove;
  final Key removeKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isCover ? DealGoColors.primary : DealGoColors.border,
                    width: isCover ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: child,
              ),
            ),
            if (isCover)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DealGoColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    coverLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else if (isStagedNew)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DealGoColors.brandGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    newLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.65),
                shape: const CircleBorder(),
                child: InkWell(
                  key: removeKey,
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      DealGoIcons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineOptionGroupSheet extends StatefulWidget {
  const _InlineOptionGroupSheet({this.group});

  final FoodOptionGroup? group;

  @override
  State<_InlineOptionGroupSheet> createState() =>
      _InlineOptionGroupSheetState();
}

class _InlineOptionGroupSheetState extends State<_InlineOptionGroupSheet> {
  late final _title = TextEditingController(text: widget.group?.title ?? '');
  late final _min = TextEditingController(
    text: '${widget.group?.minSelect ?? 0}',
  );
  late final _max = TextEditingController(
    text: '${widget.group?.maxSelect ?? 1}',
  );
  List<FoodOptionChoice>? _choices;
  final _choiceLabel = TextEditingController();
  final _choiceExtra = TextEditingController(text: '0');

  List<FoodOptionChoice> _resolvedChoices(AppLocalizations l10n) {
    return _choices ??= List<FoodOptionChoice>.of(
      widget.group?.choices ??
          [
            FoodOptionChoice(
              id: '',
              label: l10n.merchantItemOptionsDefaultChoice,
              extraVnd: 0,
            ),
          ],
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _min.dispose();
    _max.dispose();
    _choiceLabel.dispose();
    _choiceExtra.dispose();
    super.dispose();
  }

  void _addChoice(List<FoodOptionChoice> choices) {
    final label = _choiceLabel.text.trim();
    final extra = int.tryParse(_choiceExtra.text.trim()) ?? 0;
    if (label.isEmpty || choices.length >= merchantOptionMaxChoices) return;
    setState(() {
      choices.add(FoodOptionChoice(id: '', label: label, extraVnd: extra));
      _choiceLabel.clear();
      _choiceExtra.text = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final choices = _resolvedChoices(l10n);
    final minSelect = int.tryParse(_min.text.trim()) ?? -1;
    final maxSelect = int.tryParse(_max.text.trim()) ?? -1;
    final valid =
        _title.text.trim().isNotEmpty &&
        minSelect >= 0 &&
        maxSelect >= 1 &&
        minSelect <= maxSelect &&
        choices.isNotEmpty &&
        minSelect <= choices.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s20,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.merchantOptionsGroupDialogTitle,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoTextField(
                label: l10n.merchantOptionsGroupName,
                fieldKey: const Key('merchant-inline-group-title'),
                controller: _title,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Row(
                children: [
                  Expanded(
                    child: DealGoTextField(
                      label: l10n.merchantOptionsMin,
                      controller: _min,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: DealGoTextField(
                      label: l10n.merchantOptionsMax,
                      controller: _max,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Text(
                l10n.merchantItemOptionsChoicesCount(choices.length),
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              for (var i = 0; i < choices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: DealGoSpacing.s4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${choices[i].label} (+${formatVnd(choices[i].extraVnd)})',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          DealGoIcons.close,
                          size: 16,
                          color: DealGoColors.danger,
                        ),
                        onPressed: () => setState(() => choices.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: DealGoSpacing.s8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: DealGoTextField(
                      label: l10n.merchantOptionsChoiceName,
                      controller: _choiceLabel,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    flex: 2,
                    child: DealGoTextField(
                      label: l10n.merchantOptionsChoicePrice,
                      controller: _choiceExtra,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: DealGoColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _addChoice(choices),
                    icon: const Icon(
                      DealGoIcons.add,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s20),
              if (widget.group != null) ...[
                DealGoSecondaryButton(
                  label: l10n.merchantOptionsDelete,
                  tone: DealGoSecondaryTone.danger,
                  compact: true,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).pop(
                      const FoodOptionGroup(
                        id: '',
                        title: '',
                        minSelect: 0,
                        maxSelect: 1,
                        choices: [],
                      ),
                    );
                  },
                ),
                const SizedBox(height: DealGoSpacing.s8),
              ],
              Row(
                children: [
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: l10n.actionCancel,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: DealGoPrimaryButton(
                      key: const Key('merchant-inline-group-apply'),
                      label: l10n.merchantOptionsApply,
                      compact: true,
                      enabled: valid,
                      onPressed: () {
                        if (!valid) return;
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop(
                          FoodOptionGroup(
                            id: widget.group?.id ?? '',
                            title: _title.text.trim(),
                            minSelect: minSelect,
                            maxSelect: maxSelect,
                            choices: List.unmodifiable(choices),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
