import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/drafts/text_draft.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../l10n/app_localizations.dart';

import 'dart:convert';

import '../../../food/domain/entities/food_models.dart';
import '../../../onboarding/presentation/document_image_source.dart';
import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../domain/entities/merchant_menu_models.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

/// M027 — edit name/price/description/prep/category/availability (DEC-PROD-039).
class MerchantItemEditPage extends StatefulWidget {
  const MerchantItemEditPage({super.key, required this.itemId, this.initial});

  final String itemId;
  final FoodMenuItem? initial;

  @override
  State<MerchantItemEditPage> createState() => _MerchantItemEditPageState();
}

class _MerchantItemEditPageState extends State<MerchantItemEditPage>
    with TextDraftMixin {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _originalPrice = TextEditingController();
  int? _loadedOriginalPrice;
  final _description = TextEditingController();
  final _prep = TextEditingController();
  var _available = true;
  String? _categoryId;
  var _loading = true;
  var _formReady = false;
  var _missing = false;
  Object? _loadFailure;
  var _busy = false;
  var _uploadingPhoto = false;
  String? _error;
  String? _imageUrl;
  List<String> _imageUrls = const [];
  int _soldCount = 0;
  List<MerchantMenuCategory> _categories = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
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
      FoodMenuItem? item = widget.initial;
      if (item == null || item.id != widget.itemId) {
        final store = await repo.getMerchantCatalog(token);
        for (final row in store.items) {
          if (row.id == widget.itemId) {
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
      _description.text = item.description ?? '';
      _prep.text = item.prepMinutes?.toString() ?? '';
      _available = item.available;
      _categoryId = item.menuCategoryId;
      _imageUrl = item.imageUrl;
      _imageUrls = item.imageUrls.isNotEmpty
          ? item.imageUrls
          : (item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? [item.imageUrl!]
                : const []);
      _soldCount = item.soldCount;
      setState(() {
        _categories = cats;
        _loading = false;
        _formReady = true;
        _loadFailure = null;
        _missing = false;
      });
      // Unsaved edits of this item survive an app kill (text fields only).
      bindTextDraft('merchant.item.${widget.itemId}', {
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

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto || _busy) return;
    final source = context.read<DocumentImageSource>();
    final picked = await source.pick(camera: false);
    if (picked == null || !mounted) return;
    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });
    try {
      final updated = await context
          .read<MerchantOrdersRepository>()
          .uploadItemImage(
            accessToken: merchantAccessToken(context) ?? '',
            itemId: widget.itemId,
            contentBase64: base64Encode(picked.bytes),
            contentType: picked.contentType,
          );
      if (!mounted) return;
      setState(() {
        _imageUrl = updated.imageUrl;
        _imageUrls = updated.imageUrls.isNotEmpty
            ? updated.imageUrls
            : (updated.imageUrl != null && updated.imageUrl!.isNotEmpty
                  ? [updated.imageUrl!]
                  : const []);
        _uploadingPhoto = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _error = apiErrorText(AppLocalizations.of(context), e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _error = AppLocalizations.of(context).merchantItemPhotoError;
        });
      }
    }
  }

  Future<void> _clearPhoto() async {
    if (_uploadingPhoto || _busy || _imageUrl == null) return;
    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });
    try {
      final updated = await context
          .read<MerchantOrdersRepository>()
          .clearItemImage(
            accessToken: merchantAccessToken(context) ?? '',
            itemId: widget.itemId,
          );
      if (!mounted) return;
      setState(() {
        _imageUrl = updated.imageUrl;
        _imageUrls = updated.imageUrls;
        _uploadingPhoto = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _error = apiErrorText(AppLocalizations.of(context), e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _error = AppLocalizations.of(context).merchantItemPhotoError;
        });
      }
    }
  }

  Future<void> _save({required bool continueToVariants}) async {
    if (_busy) return;
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    final prepText = _prep.text.trim();
    final prep = prepText.isEmpty ? null : int.tryParse(prepText);
    if (name.isEmpty || price == null || price < 1) {
      setState(() => _error = AppLocalizations.of(context).merchantItemInvalid);
      return;
    }
    if (prepText.isNotEmpty && (prep == null || prep < 1 || prep > 240)) {
      setState(() => _error = AppLocalizations.of(context).merchantItemInvalid);
      return;
    }
    final originalText = _originalPrice.text.trim();
    final original = originalText.isEmpty ? null : int.tryParse(originalText);
    if (originalText.isNotEmpty && (original == null || original <= price)) {
      setState(
        () =>
            _error = AppLocalizations.of(context)
                .merchantItemOriginalPriceInvalid,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<MerchantOrdersRepository>().updateCatalogItem(
        accessToken: merchantAccessToken(context) ?? '',
        itemId: widget.itemId,
        name: name,
        priceVnd: price,
        available: _available,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        prepMinutes: prep,
        menuCategoryId: _categoryId,
        originalPriceVnd: original,
        clearOriginalPrice: original == null && _loadedOriginalPrice != null,
      );
      clearTextDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).merchantItemSaved)),
      );
      if (continueToVariants) {
        context.push(
          MerchantRoutes.itemVariants(widget.itemId, itemName: name),
        );
      } else {
        context.pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorText(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return MerchantPageFrame(
      title: l10n.merchantItemEditTitle,
      onBack: () => merchantBack(context),
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
                  Text(
                    l10n.merchantItemInfo,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),

                  Text(
                    _available
                        ? l10n.merchantEditStatusOnSale
                        : l10n.merchantEditStatusHidden,
                    key: const Key('merchant-edit-status'),
                    style: textTheme.labelLarge?.copyWith(
                      color: _available
                          ? DealGoColors.primary
                          : DealGoColors.danger,
                    ),
                  ),
                  if (_soldCount > 0) ...[
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(l10n.merchantProductsSoldCount('$_soldCount')),
                  ],
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(l10n.merchantItemPhoto, style: textTheme.titleSmall),
                  const SizedBox(height: DealGoSpacing.s8),
                  SizedBox(
                    height: 88,
                    child: ListView(
                      key: const Key('merchant-edit-gallery'),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final url in _imageUrls) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              right: DealGoSpacing.s8,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 88,
                                height: 88,
                                child: DealGoNetworkImage(
                                  resolveMediaUrl(url) ?? url,
                                  fit: BoxFit.cover,
                                  fallback: const ColoredBox(
                                    color: DealGoColors.subtlePurple,
                                    child: Icon(
                                      DealGoIcons.restaurant,
                                      color: DealGoColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_imageUrls.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(right: DealGoSpacing.s8),
                            child: SizedBox(
                              width: 88,
                              height: 88,
                              child: ColoredBox(
                                color: DealGoColors.subtlePurple,
                                child: Icon(
                                  DealGoIcons.restaurant,
                                  color: DealGoColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('merchant-edit-photo-pick'),
                          onPressed: _uploadingPhoto || _busy
                              ? null
                              : _pickPhoto,
                          child: _uploadingPhoto
                              ? Text(l10n.merchantItemPhotoUploading)
                              : Text(l10n.merchantItemPhotoPick),
                        ),
                      ),
                      if (_imageUrls.isNotEmpty) ...[
                        const SizedBox(width: DealGoSpacing.s8),
                        TextButton(
                          key: const Key('merchant-edit-photo-clear'),
                          onPressed: _uploadingPhoto || _busy
                              ? null
                              : _clearPhoto,
                          child: Text(l10n.merchantItemPhotoClear),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  DealGoTextField(
                    label: l10n.merchantItemName,
                    fieldKey: const Key('merchant-edit-name'),
                    controller: _name,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoTextField(
                    label: l10n.merchantItemPrice,
                    fieldKey: const Key('merchant-edit-price'),
                    controller: _price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoTextField(
                    label: l10n.merchantItemOriginalPrice,
                    fieldKey: const Key('merchant-edit-original-price'),
                    controller: _originalPrice,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoTextField(
                    label: l10n.merchantItemDescription,
                    fieldKey: const Key('merchant-edit-description'),
                    controller: _description,
                    maxLines: 3,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoTextField(
                    label: l10n.merchantItemPrep,
                    fieldKey: const Key('merchant-edit-prep'),
                    controller: _prep,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DropdownButtonFormField<String?>(
                    key: const Key('merchant-edit-category'),
                    initialValue: _categoryId,
                    decoration: InputDecoration(
                      labelText: l10n.merchantItemCategory,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('—'),
                      ),
                      for (final cat in _categories)
                        DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  SwitchListTile.adaptive(
                    key: const Key('merchant-edit-available'),
                    title: Text(l10n.merchantItemVisible),
                    subtitle: Text(l10n.merchantItemVisibleBody),
                    value: _available,
                    onChanged: (v) => setState(() => _available = v),
                  ),
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: DealGoColors.danger)),
                  const SizedBox(height: DealGoSpacing.s16),
                  IntrinsicHeight(
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
                ],
              ),
            ),
    );
  }
}
