import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/driver_duty_cubit.dart';
import '../widgets/driver_widgets.dart';

/// D017 — service toggles / duty configuration (local mock persistence).
class DriverServicesPage extends StatefulWidget {
  const DriverServicesPage({super.key});

  @override
  State<DriverServicesPage> createState() => _DriverServicesPageState();
}

class _DriverServicesPageState extends State<DriverServicesPage> {
  var _rideOn = true;
  var _foodOn = true;
  var _saved = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final online = context.watch<DriverDutyCubit>().state;
    final approvedCount = (_rideOn ? 1 : 0) + (_foodOn ? 1 : 0);

    return Scaffold(
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
            trailingIcon: Icons.arrow_forward,
            onPressed: () => setState(() => _saved = true),
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
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              l10n.driverServicesBody,
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s16),
            DriverPanel(
              color: DealGoColors.greenSurface,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: DealGoColors.brandGreen,
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.driverServicesOnlineTitle,
                          style: textTheme.titleMedium,
                        ),
                        Text(
                          l10n.driverServicesOnlineBody,
                          style: textTheme.bodySmall,
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
                  l10n.driverServicesCount(approvedCount),
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
                    icon: Icons.two_wheeler,
                    iconColor: DealGoColors.primary,
                    title: l10n.driverServicesRideTitle,
                    subtitle: l10n.driverServicesRideBody,
                    approvedLabel: l10n.driverServicesApprovedChip,
                    value: _rideOn,
                    onChanged: (value) => setState(() => _rideOn = value),
                  ),
                  const Divider(height: 1),
                  _ServiceRow(
                    key: const Key('driver-services-food'),
                    icon: Icons.storefront_outlined,
                    iconColor: DealGoColors.brandGreen,
                    title: l10n.driverServicesFoodTitle,
                    subtitle: l10n.driverServicesFoodBody,
                    approvedLabel: l10n.driverServicesApprovedChip,
                    value: _foodOn,
                    onChanged: (value) => setState(() => _foodOn = value),
                  ),
                ],
              ),
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
                          l10n.driverServicesVehicleSection,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      DriverChip(
                        label: l10n.driverServicesVehicleInUse,
                        tone: DriverChipTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Row(
                    children: [
                      const Icon(
                        Icons.two_wheeler,
                        color: DealGoColors.brandGreen,
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Honda Vision · 2023',
                              style: textTheme.titleMedium,
                            ),
                            Text(
                              'Biển số 43H1-123.45',
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.driverServicesAreaSection,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        l10n.driverServicesAreaEdit,
                        style: textTheme.labelLarge?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(driverAreaLabel, style: textTheme.bodyMedium),
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
                            Icons.place_outlined,
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
            const SizedBox(height: DealGoSpacing.s12),
            Text(
              l10n.driverServicesPolicyHint,
              style: textTheme.bodySmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
            if (_saved) ...[
              const SizedBox(height: DealGoSpacing.s12),
              const DriverNote(
                tone: DriverNoteTone.green,
                message: 'Đã lưu cấu hình trên máy (mock). Quyền nhận việc vẫn do máy chủ xét.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.approvedLabel,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String approvedLabel;
  final bool value;
  final ValueChanged<bool> onChanged;

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
              child: Icon(icon, color: iconColor),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(subtitle, style: textTheme.bodySmall),
                const SizedBox(height: DealGoSpacing.s8),
                DriverChip(label: approvedLabel, tone: DriverChipTone.green),
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
