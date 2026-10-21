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
import '../../../presence/domain/entities/driver_service_prefs.dart';
import '../../../shell/presentation/account_routes.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_services_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final prefs = context.watch<DriverServicesCubit>().state.saved;
    return DriverPageFrame(
      title: l10n.driverHomeTitle,
      onBack: () => driverBack(context),
      footer: DriverFooter(
        secondaryLabel: l10n.driverSeeHistory,
        primaryLabel: l10n.driverGoOnline,
        primaryKey: const Key('driver-go-online'),
        onSecondary: () => context.go(driverEarningsPath),
        onPrimary: () => context.read<DriverDutyCubit>().connect(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
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
                DriverMoneyRow(
                  label: l10n.driverServiceTypes,
                  value: driverServicesSummary(l10n, prefs),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverNote(message: l10n.driverOfflineNote),
        ],
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
      onBack: () => driverBack(context),
      footer: DriverFooter(
        secondaryLabel: l10n.driverContactSupport,
        primaryLabel: l10n.driverOpenApplication,
        primaryKey: const Key('driver-open-application'),
        onSecondary: () => context.push(AccountRoutes.help('/driver/account')),
        onPrimary: () => context.push(DriverKycRoutes.root),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
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
          const SizedBox(height: DealGoSpacing.s12),
          DriverNote(message: l10n.driverIneligibleNote),
        ],
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
      }
    });
  }

  /// Home switches save straight away; the job list then follows the new choice.
  Future<void> _toggle({bool? ride, bool? food}) async {
    final cubit = context.read<DriverServicesCubit>();
    if (ride != null) cubit.setRide(ride);
    if (food != null) cubit.setFood(food);
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

    return DriverPageFrame(
      title: l10n.driverHomeTitle,
      onBack: () => driverBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s24,
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
          const _DutyMap(),
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
                    TextButton(
                      key: const Key('driver-open-services'),
                      onPressed: () => context.push(DriverRoutes.services),
                      child: Text(l10n.driverConfigure),
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                _ServiceSwitch(
                  key: const Key('driver-home-ride-switch'),
                  icon: DealGoIcons.motorbike,
                  title: l10n.driverServicePassenger,
                  subtitle: l10n.rideVehicleMotorbike,
                  value: services.prefs.rideEnabled,
                  onChanged: services.busy
                      ? null
                      : (value) => _toggle(ride: value),
                ),
                const Divider(height: 1),
                _ServiceSwitch(
                  key: const Key('driver-home-food-switch'),
                  icon: DealGoIcons.package,
                  title: l10n.driverServicesFoodTitle,
                  subtitle: l10n.driverServicesFoodBody,
                  value: services.prefs.foodEnabled,
                  onChanged: services.busy
                      ? null
                      : (value) => _toggle(food: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverNote(
            tone: DriverNoteTone.green,
            message: l10n.driverOnlinePolicyNote,
          ),
        ],
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

class _DutyMap extends StatelessWidget {
  const _DutyMap();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: SizedBox(
        height: 180,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _DutyMapPainter()),
            const Align(
              alignment: Alignment(0.15, 0.05),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.card,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    DealGoIcons.motorbike,
                    color: DealGoColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: DealGoColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s12,
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Text(
                    AppLocalizations.of(context).driverOnDutyMapLabel,
                    style: const TextStyle(
                      color: DealGoColors.card,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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

class _DutyMapPainter extends CustomPainter {
  const _DutyMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = DealGoColors.infoSurface,
    );
    final street = Paint()
      ..color = DealGoColors.canvas
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;
    for (var y = 18.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 10), street);
    }
    for (var x = 12.0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x + 16, size.height), street);
    }
    final river = Path()
      ..moveTo(size.width * 0.62, 0)
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.45,
        size.width * 0.5,
        size.height,
      )
      ..lineTo(size.width * 0.68, size.height)
      ..quadraticBezierTo(
        size.width * 0.98,
        size.height * 0.4,
        size.width * 0.78,
        0,
      )
      ..close();
    canvas.drawPath(river, Paint()..color = DealGoColors.lavender);

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.78)
      ..lineTo(size.width * 0.18, size.height * 0.42)
      ..lineTo(size.width * 0.46, size.height * 0.42)
      ..lineTo(size.width * 0.46, size.height * 0.22)
      ..lineTo(size.width * 0.72, size.height * 0.22);
    canvas.drawPath(
      route,
      Paint()
        ..color = DealGoColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.22),
      5,
      Paint()..color = DealGoColors.danger,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    required this.icon,
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
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
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: DealGoColors.primary),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium?.copyWith(fontSize: 16)),
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

/// "Chở khách, Giao đồ ăn" from the driver's own toggles.
String driverServicesSummary(AppLocalizations l10n, DriverServicePrefs prefs) {
  final parts = [
    if (prefs.rideEnabled) l10n.driverServicePassenger,
    if (prefs.foodEnabled) l10n.driverServicesFoodTitle,
  ];
  return parts.isEmpty ? l10n.driverNoServiceOn : parts.join(', ');
}
