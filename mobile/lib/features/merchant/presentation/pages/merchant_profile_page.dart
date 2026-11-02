import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/presentation/widgets/food_category_tile.dart';
import '../../../onboarding/presentation/document_image_source.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

/// M030 — everything customers see on the store page header: cover photo, logo,
/// name, description, minimum order and category (DEC-PROD-045). Images go
/// through the shared upload pipeline (JPEG/PNG/WebP, UPLOAD_MAX_FILE_KB).
class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  final _name = TextEditingController();
  final _minOrder = TextEditingController();
  final _description = TextEditingController();
  FoodStoreDetail? _store;
  String? _category;
  Object? _loadError;
  var _saving = false;
  var _logoBusy = false;
  var _coverBusy = false;
  String? _notice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _minOrder.addListener(() => setState(() {}));
    _description.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _minOrder.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _store = null;
    });
    try {
      final store = await context.read<GetMerchantCatalog>()(
        merchantAccessToken(context) ?? '',
      );
      if (!mounted) return;
      setState(() {
        _store = store;
        _name.text = store.name;
        _category = store.category;
        _minOrder.text = store.minOrderVnd > 0 ? '${store.minOrderVnd}' : '';
        _description.text = store.description ?? '';
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  String get _trimmed => _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get _nameValid => _trimmed.length >= 2 && _trimmed.length <= 120;

  bool get _nameDirty => _store != null && _trimmed != _store!.name;

  bool get _categoryDirty =>
      _store != null && _category != null && _category != _store!.category;

  /// Empty field = no minimum.
  int? get _minOrderValue {
    final text = _minOrder.text.trim();
    if (text.isEmpty) return 0;
    final value = int.tryParse(text);
    return value == null || value > 10000000 ? null : value;
  }

  bool get _minOrderDirty =>
      _store != null &&
      _minOrderValue != null &&
      _minOrderValue != _store!.minOrderVnd;

  String get _descriptionText => _description.text.trim();

  bool get _descriptionDirty =>
      _store != null && _descriptionText != (_store!.description ?? '');

  bool get _dirty =>
      _nameDirty || _categoryDirty || _minOrderDirty || _descriptionDirty;

  bool get _valid => _nameValid && _minOrderValue != null;

  Future<void> _run(
    Future<FoodStoreDetail> Function(
      MerchantOrdersRepository repo,
      String token,
    )
    action, {
    required String done,
    _ImageSlot? image,
  }) async {
    final l10n = AppLocalizations.of(context);
    final repo = context.read<MerchantOrdersRepository>();
    final token = merchantAccessToken(context) ?? '';
    setState(() {
      switch (image) {
        case _ImageSlot.logo:
          _logoBusy = true;
        case _ImageSlot.cover:
          _coverBusy = true;
        case null:
          _saving = true;
      }
      _notice = null;
      _error = null;
    });
    try {
      final store = await action(repo, token);
      if (!mounted) return;
      setState(() {
        _store = store;
        if (image == null) {
          _name.text = store.name;
          _category = store.category;
          _minOrder.text = store.minOrderVnd > 0 ? '${store.minOrderVnd}' : '';
          _description.text = store.description ?? '';
        }
        _notice = done;
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorText(l10n, error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _logoBusy = false;
          _coverBusy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_valid || !_dirty || _saving) return;
    final name = _nameDirty ? _trimmed : null;
    final category = _categoryDirty ? _category : null;
    final minOrder = _minOrderDirty ? _minOrderValue : null;
    final description = _descriptionDirty ? _descriptionText : null;
    await _run(
      (repo, token) => repo.updateStoreProfile(
        accessToken: token,
        name: name,
        category: category,
        minOrderVnd: minOrder,
        description: description,
      ),
      done: AppLocalizations.of(context).merchantProfileSaved,
    );
  }

  Future<void> _pickLogo() async {
    if (_logoBusy) return;
    final picked = await context.read<DocumentImageSource>().pick(
      camera: false,
    );
    if (picked == null || !mounted) return;
    await _run(
      (repo, token) => repo.uploadStoreLogo(
        accessToken: token,
        contentBase64: base64Encode(picked.bytes),
        contentType: picked.contentType,
      ),
      done: AppLocalizations.of(context).merchantProfileLogoSaved,
      image: _ImageSlot.logo,
    );
  }

  Future<void> _removeLogo() async {
    if (_logoBusy || _store?.logoUrl == null) return;
    await _run(
      (repo, token) => repo.clearStoreLogo(accessToken: token),
      done: AppLocalizations.of(context).merchantProfileLogoRemoved,
      image: _ImageSlot.logo,
    );
  }

  Future<void> _pickCover() async {
    if (_coverBusy) return;
    final picked = await context.read<DocumentImageSource>().pick(
      camera: false,
    );
    if (picked == null || !mounted) return;
    await _run(
      (repo, token) => repo.uploadStoreLogo(
        accessToken: token,
        contentBase64: base64Encode(picked.bytes),
        contentType: picked.contentType,
        cover: true,
      ),
      done: AppLocalizations.of(context).merchantProfileCoverSaved,
      image: _ImageSlot.cover,
    );
  }

  Future<void> _removeCover() async {
    if (_coverBusy || _store?.coverUrl == null) return;
    await _run(
      (repo, token) => repo.clearStoreLogo(accessToken: token, cover: true),
      done: AppLocalizations.of(context).merchantProfileCoverRemoved,
      image: _ImageSlot.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = _store;
    final Widget body;
    if (_loadError != null) {
      body = DealGoStateView.failure(
        context,
        onRetry: _load,
        cause: _loadError,
        message: apiErrorText(l10n, _loadError),
      );
    } else if (store == null) {
      body = const DealGoSkeletonList(itemCount: 2);
    } else {
      body = Material(color: DealGoColors.canvas, child: _content(l10n, store));
    }
    return MerchantPageFrame(
      title: l10n.merchantProfileTitle,
      onBack: () => merchantBack(context),
      body: body,
      footer: store == null
          ? null
          : MerchantPrimaryBar(
              label: l10n.merchantProfileSave,
              buttonKey: const Key('merchant-profile-save'),
              loading: _saving,
              enabled: !_saving && _valid && _dirty,
              onPressed: _save,
            ),
    );
  }

  Widget _content(AppLocalizations l10n, FoodStoreDetail store) {
    final textTheme = Theme.of(context).textTheme;
    final logo = store.logoUrl;
    final showNameError = _name.text.isNotEmpty && !_nameValid;
    return ListView(
      padding: dealGoScrollPadding(context, merchantPagePadding),
      children: [
        if (_notice != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoBanner(
            key: const Key('merchant-profile-notice'),
            message: _notice!,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoBanner(
            key: const Key('merchant-profile-error'),
            tone: DealGoBannerTone.warning,
            message: _error!,
          ),
        ],
        const SizedBox(height: DealGoSpacing.s16),
        _coverPanel(l10n, store),
        const SizedBox(height: DealGoSpacing.s16),
        MerchantPanel(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: logo == null
                      ? ColoredBox(
                          key: Key('merchant-profile-logo-empty'),
                          color: DealGoColors.subtlePurple,
                          child: Icon(
                            DealGoIcons.restaurant,
                            color: DealGoColors.primary,
                          ),
                        )
                      : DealGoNetworkImage(
                          resolveMediaUrl(logo) ?? logo,
                          key: const Key('merchant-profile-logo'),
                          fit: BoxFit.cover,
                          fallback: ColoredBox(
                            color: DealGoColors.subtlePurple,
                            child: Icon(
                              DealGoIcons.restaurant,
                              color: DealGoColors.primary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.merchantProfileLogo, style: textTheme.titleSmall),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      children: [
                        OutlinedButton(
                          key: const Key('merchant-profile-logo-pick'),
                          onPressed: _logoBusy ? null : _pickLogo,
                          child: _logoBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  logo == null
                                      ? l10n.merchantProfileLogoAdd
                                      : l10n.merchantProfileLogoChange,
                                ),
                        ),
                        if (logo != null)
                          TextButton(
                            key: const Key('merchant-profile-logo-remove'),
                            onPressed: _logoBusy ? null : _removeLogo,
                            child: Text(l10n.merchantProfileLogoRemove),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        MerchantPanel(
          child: DealGoTextField(
            label: l10n.merchantProfileName,
            fieldKey: const Key('merchant-profile-name'),
            controller: _name,
            maxLength: 120,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            errorText: showNameError ? l10n.merchantProfileNameInvalid : null,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        MerchantPanel(
          child: DealGoTextField(
            label: l10n.merchantProfileDescription,
            fieldKey: const Key('merchant-profile-description'),
            controller: _description,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        MerchantPanel(
          child: DealGoTextField(
            label: l10n.merchantStoreMinOrder,
            fieldKey: const Key('merchant-profile-min-order'),
            controller: _minOrder,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: _minOrderValue == null
                ? l10n.merchantStoreMinOrderInvalid
                : null,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        MerchantPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.merchantProfileCategory, style: textTheme.titleSmall),
              FoodCategoryPicker(
                key: const Key('merchant-profile-category'),
                selected: _category,
                enabled: !_saving,
                onChanged: (code) => setState(() => _category = code),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPanel(AppLocalizations l10n, FoodStoreDetail store) {
    final textTheme = Theme.of(context).textTheme;
    final cover = store.coverUrl;
    final placeholder = ColoredBox(
      key: Key('merchant-profile-cover-empty'),
      color: DealGoColors.subtlePurple,
      child: Center(
        child: Icon(DealGoIcons.image, color: DealGoColors.primary, size: 32),
      ),
    );
    return MerchantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.merchantProfileCover, style: textTheme.titleSmall),
          ClipRRect(
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: AspectRatio(
              aspectRatio: 2,
              child: cover == null
                  ? placeholder
                  : DealGoNetworkImage(
                      resolveMediaUrl(cover) ?? cover,
                      key: const Key('merchant-profile-cover'),
                      fit: BoxFit.cover,
                      fallback: placeholder,
                    ),
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('merchant-profile-cover-pick'),
                  onPressed: _coverBusy ? null : _pickCover,
                  child: _coverBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          cover == null
                              ? l10n.merchantProfileCoverAdd
                              : l10n.merchantProfileCoverChange,
                        ),
                ),
              ),
              if (cover != null) ...[
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: TextButton(
                    key: const Key('merchant-profile-cover-remove'),
                    onPressed: _coverBusy ? null : _removeCover,
                    child: Text(l10n.merchantProfileCoverRemove),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

enum _ImageSlot { logo, cover }
