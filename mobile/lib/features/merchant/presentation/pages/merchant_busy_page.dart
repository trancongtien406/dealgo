import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/update_store_service_mode.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';

/// Auto-resume presets the backend accepts (DEC-PROD-026); null = manual.
const merchantResumePresets = <int?>[30, 60, 120, null];

/// M024 BUSY extra prep minutes the backend accepts (DEC-PROD-028).
const merchantBusyExtraPresets = <int>[10, 15, 20, 30, 45, 60];

/// M024 — busy / pause mode, stored on the store and enforced at order placement.
class MerchantBusyPage extends StatefulWidget {
  const MerchantBusyPage({super.key});

  @override
  State<MerchantBusyPage> createState() => _MerchantBusyPageState();
}

class _MerchantBusyPageState extends State<MerchantBusyPage> {
  FoodStoreDetail? _store;
  Object? _loadError;
  var _mode = StoreServiceMode.open;
  int? _resumeAfter = 30;
  var _busyExtra = 15;
  var _saving = false;
  String? _saveError;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _store = null;
    });
    try {
      final token = merchantAccessToken(context) ?? '';
      final store = await context.read<GetMerchantCatalog>()(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _mode = store.serviceMode;
        _busyExtra = store.acceptSettings.busyExtraMinutes;
        _resumeAfter =
            store.serviceModeUntil == null &&
                store.serviceMode != StoreServiceMode.open
            ? null
            : 30;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _saveError = null;
      _saved = false;
    });
    try {
      final token = merchantAccessToken(context) ?? '';
      final store = await context.read<UpdateStoreServiceMode>()(
        accessToken: token,
        mode: _mode,
        resumeAfterMinutes: _mode == StoreServiceMode.open
            ? null
            : _resumeAfter,
        busyExtraMinutes: _mode == StoreServiceMode.busy ? _busyExtra : null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _mode = store.serviceMode;
        _saved = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = apiErrorText(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _pick(StoreServiceMode mode) {
    setState(() {
      _mode = mode;
      _saved = false;
    });
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
      body = const DealGoSkeletonList(itemCount: 3);
    } else {
      body = Material(
        color: DealGoColors.canvas,
        child: _form(context, l10n, store),
      );
    }
    return MerchantPageFrame(
      title: l10n.merchantBusyTitle,
      onBack: () => merchantBack(context),
      body: body,
      footer: store == null
          ? null
          : MerchantPrimaryBar(
              label: l10n.merchantBusySave,
              buttonKey: const Key('merchant-busy-save'),
              loading: _saving,
              enabled: !_saving,
              onPressed: _save,
            ),
    );
  }

  Widget _form(
    BuildContext context,
    AppLocalizations l10n,
    FoodStoreDetail store,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final accepting = _mode != StoreServiceMode.paused;
    final until = store.serviceModeUntil;
    return ListView(
      padding: dealGoScrollPadding(context, merchantPagePadding),
      children: [
        MerchantPanel(
          color: accepting
              ? DealGoColors.greenSurface
              : DealGoColors.dangerSurface,
          child: Row(
            children: [
              Icon(
                accepting ? DealGoIcons.success : DealGoIcons.error,
                color: accepting
                    ? DealGoColors.brandGreen
                    : DealGoColors.danger,
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accepting
                          ? l10n.merchantBusyAccepting
                          : l10n.merchantBusyNotAccepting,
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      accepting
                          ? l10n.merchantBusyAcceptingBody(store.name)
                          : l10n.merchantBusyNotAcceptingBody,
                      style: textTheme.bodySmall,
                    ),
                    if (store.serviceMode != StoreServiceMode.open &&
                        until != null)
                      Text(
                        l10n.merchantBusyResumesAt(
                          MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay.fromDateTime(until.toLocal()),
                            alwaysUse24HourFormat: true,
                          ),
                        ),
                        key: const Key('merchant-busy-resumes'),
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                key: const Key('merchant-busy-switch'),
                value: accepting,
                onChanged: (on) =>
                    _pick(on ? StoreServiceMode.open : StoreServiceMode.paused),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(l10n.merchantBusyModeLabel, style: textTheme.titleSmall),
        const SizedBox(height: DealGoSpacing.s8),
        for (final (mode, icon, color, title, hint) in [
          (
            StoreServiceMode.open,
            DealGoIcons.check,
            DealGoColors.brandGreen,
            l10n.merchantBusyOpen,
            l10n.merchantBusyOpenHint,
          ),
          (
            StoreServiceMode.busy,
            DealGoIcons.clock,
            DealGoColors.primary,
            l10n.merchantBusyBusy,
            l10n.merchantBusyBusyHint,
          ),
          (
            StoreServiceMode.paused,
            DealGoIcons.close,
            DealGoColors.danger,
            l10n.merchantBusyPaused,
            l10n.merchantBusyPausedHint,
          ),
        ]) ...[
          MerchantOptionTile(
            key: Key('merchant-busy-${mode.wire.toLowerCase()}'),
            icon: icon,
            color: color,
            title: title,
            hint: hint,
            selected: _mode == mode,
            onTap: () => _pick(mode),
          ),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        if (_mode == StoreServiceMode.busy) ...[
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.merchantBusyExtraLabel, style: textTheme.titleSmall),
                const SizedBox(height: DealGoSpacing.s8),
                Wrap(
                  spacing: DealGoSpacing.s8,
                  runSpacing: DealGoSpacing.s8,
                  children: [
                    for (final minutes in merchantBusyExtraPresets)
                      DealGoChip(
                        key: Key('merchant-busy-extra-$minutes'),
                        label: '+${l10n.merchantBusyResumeMinutes(minutes)}',
                        selected: _busyExtra == minutes,
                        onTap: () => setState(() {
                          _busyExtra = minutes;
                          _saved = false;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  l10n.merchantBusyExtraHint(
                    store.acceptSettings.defaultPrepMinutes + _busyExtra,
                  ),
                  key: const Key('merchant-busy-extra-hint'),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        if (_mode != StoreServiceMode.open) ...[
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.merchantBusyResumeLabel, style: textTheme.titleSmall),
                const SizedBox(height: DealGoSpacing.s8),
                Wrap(
                  spacing: DealGoSpacing.s8,
                  runSpacing: DealGoSpacing.s8,
                  children: [
                    for (final minutes in merchantResumePresets)
                      DealGoChip(
                        key: Key('merchant-busy-resume-${minutes ?? 'manual'}'),
                        label: switch (minutes) {
                          null => l10n.merchantBusyResumeManual,
                          < 60 => l10n.merchantBusyResumeMinutes(minutes),
                          _ => l10n.merchantBusyResumeHours(minutes ~/ 60),
                        },
                        selected: _resumeAfter == minutes,
                        onTap: () => setState(() {
                          _resumeAfter = minutes;
                          _saved = false;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        if (_saveError case final error?) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Text(
            error,
            key: const Key('merchant-busy-error'),
            style: textTheme.bodySmall?.copyWith(color: DealGoColors.danger),
          ),
        ],
        if (_saved) ...[
          const SizedBox(height: DealGoSpacing.s12),
          MerchantNote(
            key: const Key('merchant-busy-saved'),
            tone: MerchantNoteTone.green,
            message: l10n.merchantBusySaved,
          ),
        ],
      ],
    );
  }
}
