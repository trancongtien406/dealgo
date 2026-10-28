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
import '../../domain/usecases/update_store_accept_settings.dart';
import '../widgets/merchant_widgets.dart';
import 'merchant_hours_page.dart' show merchantLastOrderPresets;
import '../../../../core/design_system/components/dealgo_nav_insets.dart';

/// Kitchen caps offered in the picker; null = no cap (backend allows 1–50).
const merchantMaxActivePresets = <int?>[null, 3, 5, 8, 10, 15, 20, 30];

/// Default prep presets (backend allows 5–90).
const merchantPrepPresets = <int>[5, 10, 15, 20, 25, 30, 45, 60];

/// M022 — manual/auto accept, kitchen cap, default prep time and the shared
/// last-order cut-off, saved to the backend and enforced at checkout (DEC-PROD-028).
class MerchantAcceptSettingsPage extends StatefulWidget {
  const MerchantAcceptSettingsPage({super.key});

  @override
  State<MerchantAcceptSettingsPage> createState() =>
      _MerchantAcceptSettingsPageState();
}

class _MerchantAcceptSettingsPageState
    extends State<MerchantAcceptSettingsPage> {
  FoodStoreDetail? _store;
  Object? _loadError;
  var _settings = const StoreAcceptSettings();
  var _lastOrder = 0;
  var _saving = false;
  var _saved = false;
  String? _saveError;

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
      if (mounted) {
        _adopt(store);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    }
  }

  void _adopt(FoodStoreDetail store) {
    setState(() {
      _store = store;
      _settings = store.acceptSettings;
      _lastOrder = store.schedule.lastOrderMinutes;
    });
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
      final store = await context.read<UpdateStoreAcceptSettings>()(
        accessToken: token,
        settings: _settings,
        lastOrderMinutes: _lastOrder,
      );
      if (!mounted) {
        return;
      }
      _adopt(store);
      setState(() => _saved = true);
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

  void _change(StoreAcceptSettings next) {
    setState(() {
      _settings = next;
      _saved = false;
    });
  }

  Future<void> _pick<T>({
    required String keyPrefix,
    required List<T> options,
    required T current,
    required String Function(T value) label,
    required ValueChanged<T> onPicked,
  }) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<(T,)>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s16,
            0,
            DealGoSpacing.s16,
            DealGoSpacing.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.merchantAcceptPickTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Wrap(
                spacing: DealGoSpacing.s8,
                runSpacing: DealGoSpacing.s8,
                children: [
                  for (final option in options)
                    DealGoChip(
                      key: Key('$keyPrefix-${option ?? 'none'}'),
                      label: label(option),
                      selected: option == current,
                      onTap: () => Navigator.of(sheetContext).pop((option,)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      onPicked(picked.$1);
    }
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
      body = const DealGoSkeletonList(itemCount: 4);
    } else {
      body = Material(
        color: DealGoColors.canvas,
        child: _form(context, l10n, store),
      );
    }
    return MerchantPageFrame(
      title: l10n.merchantAcceptTitle,
      onBack: () => merchantBack(context),
      body: body,
      footer: store == null
          ? null
          : MerchantPrimaryBar(
              label: l10n.merchantAcceptSave,
              buttonKey: const Key('merchant-accept-save'),
              loading: _saving,
              enabled: !_saving,
              onPressed: _save,
            ),
    );
  }

  String _stateLabel(AppLocalizations l10n, FoodStoreDetail store) {
    return switch (store.closedReason) {
      StoreClosedReason.paused => l10n.merchantAcceptStatePaused,
      StoreClosedReason.closed => l10n.merchantAcceptStateClosed,
      null =>
        store.serviceMode == StoreServiceMode.busy
            ? l10n.merchantAcceptStateBusy
            : l10n.merchantAcceptStateOpen,
    };
  }

  Widget _form(
    BuildContext context,
    AppLocalizations l10n,
    FoodStoreDetail store,
  ) {
    final textTheme = Theme.of(context).textTheme;
    String maxLabel(int? value) => value == null
        ? l10n.merchantAcceptNoLimit
        : l10n.merchantAcceptOrdersCount(value);
    String minutesLabel(int value) => value == 0
        ? l10n.merchantHoursCutoffNone
        : l10n.merchantBusyResumeMinutes(value);
    return ListView(
      padding: dealGoScrollPadding(context, merchantPagePadding),
      children: [
        Text(
          l10n.merchantAcceptEyebrow,
          style: textTheme.labelSmall?.copyWith(
            color: DealGoColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s4),
        Text(l10n.merchantAcceptHeading, style: textTheme.headlineSmall),
        const SizedBox(height: DealGoSpacing.s16),
        MerchantPanel(
          color: DealGoColors.subtlePurple,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.greenSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(DealGoSpacing.s12),
                  child: Icon(
                    DealGoIcons.food,
                    color: DealGoColors.brandGreen,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: textTheme.titleMedium),
                    Text(
                      l10n.merchantAcceptStoreState(_stateLabel(l10n, store)),
                      key: const Key('merchant-accept-store-state'),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(l10n.merchantAcceptModeLabel, style: textTheme.titleSmall),
        const SizedBox(height: DealGoSpacing.s8),
        MerchantOptionTile(
          key: const Key('merchant-accept-manual'),
          icon: DealGoIcons.check,
          color: DealGoColors.primary,
          title: l10n.merchantAcceptManual,
          hint: l10n.merchantAcceptManualHint,
          selected: _settings.acceptMode == StoreAcceptMode.manual,
          onTap: () =>
              _change(_settings.copyWith(acceptMode: StoreAcceptMode.manual)),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        MerchantOptionTile(
          key: const Key('merchant-accept-auto'),
          icon: DealGoIcons.clock,
          color: DealGoColors.brandGreen,
          title: l10n.merchantAcceptAuto,
          hint: l10n.merchantAcceptAutoHint,
          selected: _settings.acceptMode == StoreAcceptMode.auto,
          onTap: () =>
              _change(_settings.copyWith(acceptMode: StoreAcceptMode.auto)),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(l10n.merchantAcceptLimits, style: textTheme.titleSmall),
        const SizedBox(height: DealGoSpacing.s8),
        MerchantPanel(
          child: Column(
            children: [
              _LimitRow(
                key: const Key('merchant-accept-max'),
                title: l10n.merchantAcceptMaxActive,
                value: maxLabel(_settings.maxActiveOrders),
                onTap: () => _pick<int?>(
                  keyPrefix: 'merchant-accept-max-option',
                  options: merchantMaxActivePresets,
                  current: _settings.maxActiveOrders,
                  label: maxLabel,
                  onPicked: (value) => _change(
                    _settings.copyWith(
                      maxActiveOrders: value,
                      clearMaxActiveOrders: value == null,
                    ),
                  ),
                ),
              ),
              const Divider(height: DealGoSpacing.s24),
              _LimitRow(
                key: const Key('merchant-accept-prep'),
                title: l10n.merchantAcceptPrep,
                value: minutesLabel(_settings.defaultPrepMinutes),
                onTap: () => _pick<int>(
                  keyPrefix: 'merchant-accept-prep-option',
                  options: merchantPrepPresets,
                  current: _settings.defaultPrepMinutes,
                  label: minutesLabel,
                  onPicked: (value) =>
                      _change(_settings.copyWith(defaultPrepMinutes: value)),
                ),
              ),
              const Divider(height: DealGoSpacing.s24),
              _LimitRow(
                key: const Key('merchant-accept-cutoff'),
                title: l10n.merchantAcceptCutoff,
                value: minutesLabel(_lastOrder),
                onTap: () => _pick<int>(
                  keyPrefix: 'merchant-accept-cutoff-option',
                  options: merchantLastOrderPresets,
                  current: _lastOrder,
                  label: minutesLabel,
                  onPicked: (value) => setState(() {
                    _lastOrder = value;
                    _saved = false;
                  }),
                ),
              ),
            ],
          ),
        ),
        if (_saveError case final error?) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Text(
            error,
            key: const Key('merchant-accept-error'),
            style: textTheme.bodySmall?.copyWith(color: DealGoColors.danger),
          ),
        ],
        if (_saved) ...[
          const SizedBox(height: DealGoSpacing.s12),
          MerchantNote(
            key: const Key('merchant-accept-saved'),
            tone: MerchantNoteTone.green,
            message: l10n.merchantAcceptSaved,
          ),
        ],
      ],
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title, style: textTheme.titleSmall)],
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s4,
              ),
              child: Text(
                value,
                style: textTheme.labelMedium?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
