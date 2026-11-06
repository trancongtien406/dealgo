import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../../core/network/api_exception.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';
import '../../../driver_history/domain/driver_history.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../onboarding/presentation/utils/driver_kyc_routes.dart';
import '../../../onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../../../ride/presentation/cubit/vehicle_class_catalog_cubit.dart';
import '../../../ride/presentation/utils/ride_vehicle_label.dart';
import '../../../shell/presentation/account_routes.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_services_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../utils/driver_routes.dart';
import '../utils/driver_service_icons.dart';
import '../widgets/driver_service_strip.dart';
import '../widgets/driver_widgets.dart';
import '../widgets/driver_duty_map.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<DriverFeedCubit>().state;
    final online = context.watch<DriverDutyCubit>().state;
    if (feed is DriverFeedIneligible) {
      return const DriverIneligibleView();
    }
    if (!online) {
      return const DriverOfflineView();
    }
    return const DriverOnlineView();
  }
}

class DriverOfflineView extends StatelessWidget {
  const DriverOfflineView({super.key});

  Future<void> _refresh(BuildContext context) async {
    context.read<DriverServicesCubit>().load();
    context.read<DriverKycCubit>().refresh();
    context.read<VehicleClassCatalogCubit>().load();
    await context.read<DriverFeedCubit>().sync(
      online: context.read<DriverDutyCubit>().state,
      accessToken: driverAccessToken(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final prefs = context.watch<DriverServicesCubit>().state.saved;
    final vehicleClass = context.watch<DriverKycCubit>().state.vehicleClassCode;
    return DriverPageFrame(
      title: l10n.driverHomeTitle,
      showBack: false,
      footer: DriverFooter(
        secondaryLabel: l10n.driverSeeHistory,
        primaryLabel: l10n.driverGoOnline,
        primaryKey: const Key('driver-go-online'),
        onSecondary: () => context.go(driverEarningsPath),
        onPrimary: () => context.read<DriverDutyCubit>().connect(),
      ),
      body: DealGoRefresh(
        onRefresh: () => _refresh(context),
        child: ListView(
          padding: dealGoScrollPadding(
            context,
            const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s12,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
          ),
          children: [
            DriverHero(
              icon: DealGoIcons.bolt,
              iconColor: DealGoColors.amber,
              background: DealGoColors.amberSurface,
              title: l10n.rideYouAreOffline,
              message: l10n.driverOfflineHeroMessage,
            ),
            const SizedBox(height: DealGoSpacing.s24),
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.driverDutyStatus, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverChip(
                    label: l10n.driverOfflineChip,
                    tone: DriverChipTone.warning,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text(l10n.driverServiceTypes, style: textTheme.titleSmall),
                  const SizedBox(height: DealGoSpacing.s8),
                  DriverServiceStrip(
                    prefs: prefs,
                    vehicleClassCode: vehicleClass,
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

/// Shown when the server answers ROLE_NOT_ACTIVE: the driver role is not (or no longer)
/// approved. The cause lives in the KYC application, so the screen sends the driver there.
class DriverIneligibleView extends StatelessWidget {
  const DriverIneligibleView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return DriverPageFrame(
      title: l10n.driverHomeTitle,
      showBack: false,
      footer: DriverFooter(
        secondaryLabel: l10n.driverContactSupport,
        primaryLabel: l10n.driverOpenApplication,
        primaryKey: const Key('driver-open-application'),
        onSecondary: () => context.push(AccountRoutes.help('/driver/account')),
        onPrimary: () => context.push(DriverKycRoutes.root),
      ),
      body: DealGoRefresh(
        onRefresh: () async {
          context.read<DriverKycCubit>().refresh();
          await context.read<DriverFeedCubit>().sync(
            online: context.read<DriverDutyCubit>().state,
            accessToken: driverAccessToken(context),
          );
        },
        child: ListView(
          padding: dealGoScrollPadding(
            context,
            const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s12,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
          ),
          children: [
            DriverHero(
              icon: DealGoIcons.alert,
              iconColor: DealGoColors.danger,
              background: DealGoColors.dangerSurface,
              title: l10n.driverIneligibleTitle,
              message: l10n.driverIneligibleMessage,
            ),
            const SizedBox(height: DealGoSpacing.s24),
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.driverRightsByService, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  _RightRow(
                    label: l10n.driverServicePassenger,
                    chip: l10n.driverServiceBlocked,
                    tone: DriverChipTone.danger,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  _RightRow(
                    label: l10n.driverServicesFoodTitle,
                    chip: l10n.driverServiceBlocked,
                    tone: DriverChipTone.danger,
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

class _RightRow extends StatelessWidget {
  const _RightRow({
    required this.label,
    required this.chip,
    required this.tone,
  });

  final String label;
  final String chip;
  final DriverChipTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: DealGoSpacing.s8),
        Flexible(
          child: DriverChip(label: chip, tone: tone),
        ),
      ],
    );
  }
}

class DriverOnlineView extends StatefulWidget {
  const DriverOnlineView({super.key});

  @override
  State<DriverOnlineView> createState() => _DriverOnlineViewState();
}

class _DriverOnlineViewState extends State<DriverOnlineView> {
  DriverHistorySummary? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSummary();
      if (mounted) {
        context.read<DriverServicesCubit>().load();
        context.read<DriverKycCubit>().refresh();
        context.read<VehicleClassCatalogCubit>().load();
      }
    });
  }

  /// Home switches save straight away; the job list then follows the new choice.
  Future<void> _toggle({bool? ride, bool? food, bool? parcel}) async {
    final cubit = context.read<DriverServicesCubit>();
    if (ride != null) cubit.setRide(ride);
    if (food != null) cubit.setFood(food);
    if (parcel != null) cubit.setParcel(parcel);
    final ok = await cubit.save();
    if (!mounted || ok) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).driverServicesSaveFailed),
        ),
      );
    cubit.load();
  }

  Future<void> _refresh() async {
    context.read<DriverServicesCubit>().load();
    context.read<DriverKycCubit>().refresh();
    context.read<VehicleClassCatalogCubit>().load();
    await Future.wait([
      _loadSummary(),
      context.read<DriverFeedCubit>().sync(
        online: context.read<DriverDutyCubit>().state,
        accessToken: driverAccessToken(context),
        quiet: true,
      ),
    ]);
  }

  /// Real stats from GET /v1/driver/history/summary; tiles show "—" until
  /// (or unless) it loads.
  Future<void> _loadSummary() async {
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      final summary = await context.read<DriverHistoryRepository>().summary(
        accessToken: token,
      );
      if (mounted) {
        setState(() => _summary = summary);
      }
    } on ApiException {
      // Keep placeholders.
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthCubit>().state;
    final profile = auth is AuthSignedIn ? auth.profile : null;
    final name = profile?.displayName.trim() ?? '';
    final phone = profile?.phone ?? '';
    final headline = name.isNotEmpty
        ? name
        : phone.isNotEmpty
        ? phone
        : l10n.roleDriver;
    final summary = _summary;
    final rating = summary?.ratingAverage;
    final services = context.watch<DriverServicesCubit>().state;
    final vehicleClass = context.watch<DriverKycCubit>().state.vehicleClassCode;

    return DriverPageFrame(
      title: l10n.driverHomeTitle,
      showBack: false,
      body: DealGoRefresh(
        onRefresh: _refresh,
        child: ListView(
          padding: dealGoScrollPadding(
            context,
            const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s24,
            ),
          ),
          children: [
          DriverPanel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: DealGoColors.subtlePurple,
                  child: Text(
                    headline.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline, style: textTheme.titleMedium),
                      if (name.isNotEmpty && phone.isNotEmpty)
                        Text(phone, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                _OnlineBadge(
                  onPressed: () => context.read<DriverDutyCubit>().disconnect(),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverDutyMap(
            online: context.watch<DriverDutyCubit>().state,
            vehicleClassCode: vehicleClass,
            demand: feedDemandPoints(context.watch<DriverFeedCubit>().state),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  key: const Key('driver-stat-today-jobs'),
                  label: l10n.driverStatTodayJobs,
                  value: summary == null
                      ? '—'
                      : '${summary.today.completedJobs}',
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _StatTile(
                  key: const Key('driver-stat-today-earnings'),
                  label: l10n.driverStatTodayEarnings,
                  value: summary == null
                      ? '—'
                      : formatRideVnd(summary.today.earningsVnd),
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  key: const Key('driver-stat-rating'),
                  label: l10n.driverStatRating,
                  value: rating == null || summary!.ratingCount == 0
                      ? '—'
                      : formatRatingAverage(context, rating),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _StatTile(
                  key: const Key('driver-stat-week-jobs'),
                  label: l10n.driverStatWeekJobs,
                  value: summary == null ? '—' : '${summary.weekCompletedJobs}',
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.driverAllowedServices,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const Key('driver-open-services'),
                      tooltip: l10n.driverServiceSettings,
                      onPressed: () => context.push(DriverRoutes.services),
                      icon: const Icon(DealGoIcons.tune, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                _ServiceSwitch(
                  key: const Key('driver-home-ride-switch'),
                  leading: DriverVehicleVisual(
                    vehicleClassCode: vehicleClass,
                    size: 28,
                  ),
                  title: l10n.driverServicePassenger,
                  subtitle: rideVehicleClassName(context, vehicleClass),
                  value: services.prefs.rideEnabled,
                  onChanged: services.busy
                      ? null
                      : (value) => _toggle(ride: value),
                ),
                if (driverFoodServiceVisible(vehicleClass)) ...[
                  const Divider(height: 1),
                  _ServiceSwitch(
                    key: const Key('driver-home-food-switch'),
                    leading: const Icon(
                      DriverServiceIcons.food,
                      color: DealGoColors.primary,
                    ),
                    title: l10n.driverServicesFoodTitle,
                    value: services.prefs.foodEnabled,
                    onChanged: services.busy
                        ? null
                        : (value) => _toggle(food: value),
                  ),
                ] else ...[
                  const Divider(height: 1),
                  Padding(
                    key: const Key('driver-home-food-motorbike-only'),
                    padding: const EdgeInsets.symmetric(
                      vertical: DealGoSpacing.s8,
                    ),
                    child: Text(
                      l10n.driverServicesFoodMotorbikeOnly,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
                const Divider(height: 1),
                _ServiceSwitch(
                  key: const Key('driver-home-parcel-switch'),
                  leading: const Icon(
                    DriverServiceIcons.parcel,
                    color: DealGoColors.primary,
                  ),
                  title: l10n.driverServiceParcel,
                  subtitle: l10n.driverServiceParcelHint,
                  value: services.prefs.parcelEnabled,
                  onChanged: services.busy
                      ? null
                      : (value) => _toggle(parcel: value),
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

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.greenSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const Key('driver-go-offline'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.brandGreen,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 8, height: 8),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                AppLocalizations.of(context).driverOnlineBadge,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DealGoColors.brandGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DriverPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ServiceSwitch extends StatelessWidget {
  const _ServiceSwitch({
    required this.leading,
    super.key,
    required this.title,
    this.subtitle = '',
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.canvas,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(width: 40, height: 40, child: Center(child: leading)),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium?.copyWith(fontSize: 16)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return DealGoColors.card;
            }
            return DealGoColors.textSecondary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return DealGoColors.brandGreen;
            }
            return DealGoColors.border;
          }),
        ),
      ],
    );
  }
}

const driverEarningsPath = '/driver/earnings';
