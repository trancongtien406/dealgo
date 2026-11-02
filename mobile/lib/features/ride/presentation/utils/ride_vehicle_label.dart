import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_models.dart';
import '../cubit/vehicle_class_catalog_cubit.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

IconData rideVehicleClassIcon(String? code) {
  return switch (code) {
    'CAR_7' => DealGoIcons.carSide,
    'CAR_4' => DealGoIcons.car,
    _ => DealGoIcons.motorbike,
  };
}

String rideVehicleClassLabel(AppLocalizations l10n, String? code) {
  return switch (code) {
    'CAR_4' => l10n.rideVehicleCar4Title,
    'CAR_7' => l10n.rideVehicleCar7Title,
    'MOTORBIKE' => l10n.rideVehicleBikeTitle,
    // DG-DEC-VEH-001: missing class is not silently "bike".
    null || '' => l10n.rideVehicleLabel,
    _ => code,
  };
}

/// Admin catalog name for [code] when loaded, else the built-in label.
/// Call from `build` only: it subscribes to [VehicleClassCatalogCubit].
String rideVehicleClassName(BuildContext context, String? code) {
  final adminName = context.select<VehicleClassCatalogCubit, String?>(
    (catalog) => catalog.find(code)?.name,
  );
  return adminName ?? rideVehicleClassLabel(AppLocalizations.of(context), code);
}

/// Admin-uploaded photo for the vehicle class; [icon] only when there is no
/// photo (or it fails to load). [imageUrl] wins over the catalog photo so a
/// ride keeps the image it was booked with.
class RideVehicleClassVisual extends StatelessWidget {
  const RideVehicleClassVisual({
    required this.code,
    required this.icon,
    this.imageUrl,
    this.size = 24,
    this.color = DealGoColors.primary,
    super.key,
  });

  final String? code;
  final IconData icon;
  final String? imageUrl;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final catalogImage = context.select<VehicleClassCatalogCubit, String?>(
      (catalog) => catalog.find(code)?.imageUrl,
    );
    final resolved = resolveMediaUrl(imageUrl) ?? resolveMediaUrl(catalogImage);
    final fallback = Icon(icon, size: size, color: color);
    if (resolved == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: DealGoNetworkImage(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.contain,
        fallback: fallback,
      ),
    );
  }
}

class RideVehicleClassPhoto extends StatelessWidget {
  const RideVehicleClassPhoto({
    required this.imageUrl,
    this.code,
    this.size = 32,
    super.key,
  });

  final String? imageUrl;
  final String? code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    if (resolved == null) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.input),
      child: SizedBox(
        width: size,
        height: size,
        child: DealGoNetworkImage(
          resolved,
          fit: BoxFit.cover,
          fallback: _RideVehicleClassArt(code: code, size: size),
        ),
      ),
    );
  }
}

class _RideVehicleClassArt extends StatelessWidget {
  const _RideVehicleClassArt({required this.code, required this.size});

  final String? code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final vehicleCode = code;
    if (vehicleCode == null ||
        vehicleCode.isEmpty ||
        vehicleCode == 'MOTORBIKE') {
      return Image.asset(
        'assets/images/vehicle_scooter_white.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          rideVehicleClassIcon(vehicleCode),
          size: size * 0.7,
          color: DealGoColors.brandGreen,
        ),
      );
    }
    return Icon(
      rideVehicleClassIcon(vehicleCode),
      size: size * 0.7,
      color: DealGoColors.brandGreen,
    );
  }
}

String rideStatusText(AppLocalizations l10n, RideStatus status) {
  return switch (status) {
    RideStatus.negotiating => l10n.rideStatusNegotiating,
    RideStatus.assigned => l10n.rideStatusAssigned,
    RideStatus.driverEnRoute => l10n.rideStatusDriverEnRoute,
    RideStatus.driverArrived => l10n.rideStatusDriverArrived,
    RideStatus.inTrip => l10n.rideStatusInTrip,
    RideStatus.completed => l10n.rideStatusCompleted,
    RideStatus.cancelled => l10n.rideStatusCancelled,
    RideStatus.expired => l10n.rideStatusExpired,
  };
}
