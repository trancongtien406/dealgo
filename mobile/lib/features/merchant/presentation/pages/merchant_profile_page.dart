import 'dart:convert';

import 'package:flutter/material.dart';
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
import '../../../onboarding/presentation/document_image_source.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../widgets/merchant_widgets.dart';

/// M030 — store name and logo customers see (DEC-PROD-045). The logo goes
/// through the shared upload pipeline (JPEG/PNG/WebP, UPLOAD_MAX_FILE_KB).
class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  final _name = TextEditingController();
  FoodStoreDetail? _store;
  Object? _loadError;
  var _saving = false;
  var _logoBusy = false;
  String? _notice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
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
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  String get _trimmed => _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get _nameValid => _trimmed.length >= 2 && _trimmed.length <= 120;

  bool get _dirty => _store != null && _trimmed != _store!.name;

  Future<void> _run(
    Future<FoodStoreDetail> Function(
      MerchantOrdersRepository repo,
      String token,
    )
    action, {
    required String done,
    bool logo = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final repo = context.read<MerchantOrdersRepository>();
    final token = merchantAccessToken(context) ?? '';
    setState(() {
      if (logo) {
        _logoBusy = true;
      } else {
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
        if (!logo) _name.text = store.name;
        _notice = done;
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorText(l10n, error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _logoBusy = false;
        });
      }
    }
  }

  Future<void> _saveName() async {
    if (!_nameValid || !_dirty || _saving) return;
    final name = _trimmed;
    await _run(
      (repo, token) => repo.updateStoreProfile(accessToken: token, name: name),
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
      logo: true,
    );
  }

  Future<void> _removeLogo() async {
    if (_logoBusy || _store?.logoUrl == null) return;
    await _run(
      (repo, token) => repo.clearStoreLogo(accessToken: token),
      done: AppLocalizations.of(context).merchantProfileLogoRemoved,
      logo: true,
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
              enabled: !_saving && _nameValid && _dirty,
              onPressed: _saveName,
            ),
    );
  }

  Widget _content(AppLocalizations l10n, FoodStoreDetail store) {
    final textTheme = Theme.of(context).textTheme;
    final logo = store.logoUrl;
    final showNameError = _name.text.isNotEmpty && !_nameValid;
    return ListView(
      padding: merchantPagePadding,
      children: [
        Text(l10n.merchantProfileIntro, style: textTheme.bodySmall),
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
                      ? const ColoredBox(
                          key: Key('merchant-profile-logo-empty'),
                          color: DealGoColors.subtlePurple,
                          child: Icon(
                            DealGoIcons.restaurant,
                            color: DealGoColors.primary,
                          ),
                        )
                      : Image.network(
                          resolveMediaUrl(logo) ?? logo,
                          key: const Key('merchant-profile-logo'),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
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
                    Text(
                      l10n.merchantProfileLogoHint,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
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
            onSubmitted: (_) => _saveName(),
            errorText: showNameError ? l10n.merchantProfileNameInvalid : null,
          ),
        ),
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
      ],
    );
  }
}
