import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ride/presentation/cubit/vehicle_class_catalog_cubit.dart';
import '../../../ride/presentation/utils/ride_vehicle_label.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_services_cubit.dart';
import '../utils/driver_service_icons.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';

/// D017 — services the driver takes while online (DEC-PROD-023). Toggles are stored on the
/// server (driver presence); the vehicle comes from the driver's KYC application.
class DriverServicesPage extends StatefulWidget {
  const DriverServicesPage({super.key});

  @override
  State<DriverServicesPage> createState() => _DriverServicesPageState();
}

class _DriverServicesPageState extends State<DriverServicesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DriverServicesCubit>().load();
      context.read<DriverKycCubit>().refresh();
      context.read<VehicleClassCatalogCubit>().load(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final online = context.watch<DriverDutyCubit>().state;
    final services = context.watch<DriverServicesCubit>().state;
    final kyc = context.watch<DriverKycCubit>().state;
    final prefs = services.prefs;
    // DEC-PROD-071: FOOD is motorbike-only (server fails closed); hide it for cars.
    final foodHidden = !driverFoodServiceVisible(kyc.vehicleClassCode);
    final onCount = driverEnabledServiceCount(prefs, kyc.vehicleClassCode);
    final vehicleClassName = rideVehicleClassName(
      context,
      kyc.vehicleClassCode,
    );
    final vehicleName = [
      kyc.vehicleBrand.trim(),
      kyc.vehicleModel.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final plate = kyc.vehiclePlate.trim();

    final servicesCubit = context.read<DriverServicesCubit>();
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          servicesCubit.revertUnsaved();
        }
      },
      child: Scaffold(
        body: DriverPageFrame(
          title: l10n.driverServicesTitle,
          onBack: () => driverBack(context),
          footer: Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            child: DealGoPrimaryButton(
              key: const Key('driver-services-save'),
              label: l10n.driverServicesSave,
              trailingIcon: DealGoIcons.arrowRight,
              isLoading: services.status == DriverServicesStatus.saving,
              enabled: services.status != DriverServicesStatus.loading,
              onPressed: () => context.read<DriverServicesCubit>().save(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              Text(l10n.driverServicesHeadline, style: textTheme.titleLarge),
              const SizedBox(height: DealGoSpacing.s16),
              DriverPanel(
                color: online
                    ? DealGoColors.greenSurface
                    : DealGoColors.amberSurface,
                child: Row(
                  children: [
                    Icon(
                      online ? DealGoIcons.success : DealGoIcons.bolt,
                      color: online
                          ? DealGoColors.brandGreen
                          : DealGoColors.amber,
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            online
                                ? l10n.driverServicesOnlineTitle
                                : l10n.driverServicesOfflineTitle,
                            style: textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const Key('driver-services-online'),
                      value: online,
                      onChanged: (value) {
                        if (value) {
                          context.read<DriverDutyCubit>().connect();
                        } else {
                          context.read<DriverDutyCubit>().disconnect();
                        }
                      },
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
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
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.driverServicesApprovedSection,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    l10n.driverServicesCount(onCount),
                    style: textTheme.labelLarge?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                child: Column(
                  children: [
                    _ServiceRow(
                      key: const Key('driver-services-ride'),
                      leading: DriverVehicleVisual(
                        vehicleClassCode: kyc.vehicleClassCode,
                        size: 28,
                      ),
                      title: l10n.driverServicePassenger,
                      subtitle: vehicleClassName,
                      registered: kyc.rideService != false,
                      value: prefs.rideEnabled,
                      onChanged: services.busy
                          ? null
                          : (value) => context
                                .read<DriverServicesCubit>()
                                .setRide(value),
                    ),
                    if (foodHidden) ...[
                      const Divider(height: 1),
                      Padding(
                        key: const Key('driver-services-food-motorbike-only'),
                        padding: const EdgeInsets.symmetric(
                          vertical: DealGoSpacing.s8,
                        ),
                        child: Text(
                          l10n.driverServicesFoodMotorbikeOnly,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ] else ...[
                      const Divider(height: 1),
                      _ServiceRow(
                        key: const Key('driver-services-food'),
                        leading: const Icon(
                          DriverServiceIcons.food,
                          color: DealGoColors.primary,
                        ),
                        title: l10n.driverServicesFoodTitle,
                        registered: kyc.foodService != false,
                        value: prefs.foodEnabled,
                        onChanged: services.busy
                            ? null
                            : (value) => context
                                  .read<DriverServicesCubit>()
                                  .setFood(value),
                      ),
                    ],
                    const Divider(height: 1),
                    _ServiceRow(
                      key: const Key('driver-services-parcel'),
                      leading: const Icon(
                        DriverServiceIcons.parcel,
                        color: DealGoColors.primary,
                      ),
                      title: l10n.driverServiceParcel,
                      subtitle: l10n.driverServiceParcelHint,
                      value: prefs.parcelEnabled,
                      onChanged: services.busy
                          ? null
                          : (value) => context
                                .read<DriverServicesCubit>()
                                .setParcel(value),
                    ),
                  ],
                ),
              ),
              if (onCount == 0) ...[
                const SizedBox(height: DealGoSpacing.s12),
                DriverNote(message: l10n.driverServicesNoneOn),
              ],
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.driverServicesVehicleSection,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        DriverChip(
                          label: vehicleClassName,
                          tone: DriverChipTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Row(
                      children: [
                        DriverVehicleVisual(
                          vehicleClassCode: kyc.vehicleClassCode,
                          size: 40,
                          color: DealGoColors.brandGreen,
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          key: const Key('driver-services-vehicle'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicleName.isNotEmpty
                                    ? vehicleName
                                    : vehicleClassName,
                                style: textTheme.titleMedium,
                              ),
                              Text(
                                plate.isNotEmpty
                                    ? l10n.driverVehiclePlate(plate)
                                    : l10n.driverVehicleUnknown,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.driverServicesAreaSection,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.canvas,
                        borderRadius: BorderRadius.circular(DealGoRadius.input),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(DealGoSpacing.s12),
                        child: Row(
                          children: [
                            const Icon(
                              DealGoIcons.pin,
                              color: DealGoColors.primary,
                            ),
                            const SizedBox(width: DealGoSpacing.s8),
                            Expanded(
                              child: Text(
                                l10n.driverServicesAreaFromGps,
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (services.status == DriverServicesStatus.saved) ...[
                const SizedBox(height: DealGoSpacing.s12),
                DriverNote(
                  key: const Key('driver-services-saved'),
                  tone: DriverNoteTone.green,
                  message: l10n.driverServicesSaved,
                ),
              ],
              if (services.status == DriverServicesStatus.failed) ...[
                const SizedBox(height: DealGoSpacing.s12),
                DriverNote(
                  key: const Key('driver-services-failed'),
                  message: l10n.driverServicesSaveFailed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.leading,
    required this.title,
    this.subtitle = '',
    this.registered,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Widget leading;
  final String title;
  final String subtitle;

  /// Null when this service has no separate KYC registration (parcel).
  /// False only when the KYC application says the driver did not apply.
  final bool? registered;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: leading),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: textTheme.bodySmall),
                if (registered != null) ...[
                  const SizedBox(height: DealGoSpacing.s8),
                  DriverChip(
                    label: registered!
                        ? AppLocalizations.of(context)
                              .driverServicesApprovedChip
                        : AppLocalizations.of(context)
                              .driverServicesNotRegistered,
                    tone: registered!
                        ? DriverChipTone.green
                        : DriverChipTone.neutral,
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
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
      ),
    );
  }
}
