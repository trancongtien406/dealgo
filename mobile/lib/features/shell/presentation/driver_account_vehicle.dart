import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../onboarding/domain/entities/partner_application.dart';
import '../../onboarding/domain/repositories/partner_applications_repository.dart';
import '../../onboarding/domain/usecases/get_my_partner_application.dart';
import '../../onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../../pricing/domain/pricing.dart';
import '../../ride/presentation/utils/ride_vehicle_label.dart';

class DriverAccountVehicle extends StatefulWidget {
  const DriverAccountVehicle({super.key});

  @override
  State<DriverAccountVehicle> createState() => _DriverAccountVehicleState();
}

class _RegisteredVehicle {
  const _RegisteredVehicle({
    required this.code,
    required this.name,
    this.imageUrl,
  });

  final String code;
  final String name;
  final String? imageUrl;
}

class _DriverAccountVehicleState extends State<DriverAccountVehicle> {
  var _loading = true;
  var _failed = false;
  _RegisteredVehicle? _vehicle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn) {
      if (mounted) {
        setState(() {
          _loading = false;
          _vehicle = null;
        });
      }
      return;
    }
    try {
      final view = await GetMyPartnerApplication(
        context.read<PartnerApplicationsRepository>(),
      )(accessToken: auth.tokens.accessToken, role: DriverKycCubit.role);
      if (!mounted) {
        return;
      }
      final vehicle = view == null
          ? null
          : await _vehicleFrom(auth.tokens.accessToken, view);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _vehicle = vehicle;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
          _vehicle = null;
        });
      }
    }
  }

  Future<_RegisteredVehicle?> _vehicleFrom(
    String accessToken,
    PartnerApplicationView view,
  ) async {
    final code = _metadataText(view.metadata, 'vehicleClassCode');
    if (code == null) {
      return null;
    }
    final officialName = _metadataText(view.metadata, 'vehicleType');
    var imageUrl = _metadataText(view.metadata, 'imageUrl');
    imageUrl ??= await _classImageUrl(accessToken, code);
    return _RegisteredVehicle(
      code: code,
      name: officialName ?? '',
      imageUrl: imageUrl,
    );
  }

  Future<String?> _classImageUrl(String accessToken, String code) async {
    try {
      final classes = await context
          .read<PricingRepository>()
          .listVehicleClasses(accessToken: accessToken);
      for (final option in classes) {
        final imageUrl = option.imageUrl;
        if (option.code == code && imageUrl != null && imageUrl.isNotEmpty) {
          return imageUrl;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final vehicle = _vehicle;
    final registered = vehicle != null;
    final name = registered
        ? (vehicle.name.isNotEmpty
              ? vehicle.name
              : rideVehicleClassLabel(l10n, vehicle.code))
        : (_failed ? l10n.errorLoadFailed : l10n.driverVehicleNotOnFile);
    final imageUrl = registered ? vehicle.imageUrl : null;
    final photo = registered ? resolveMediaUrl(imageUrl) : null;
    return DealGoCard(
      key: const Key('driver-account-vehicle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.driverVehicle, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          if (_loading)
            const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                if (vehicle == null)
                  const Icon(
                    DealGoIcons.info,
                    color: DealGoColors.textSecondary,
                  )
                else if (photo == null)
                  Icon(
                    rideVehicleClassIcon(vehicle.code),
                    color: DealGoColors.brandGreen,
                  )
                else
                  RideVehicleClassPhoto(
                    imageUrl: imageUrl,
                    code: vehicle.code,
                    size: 40,
                  ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(child: Text(name, style: textTheme.titleSmall)),
                if (_failed)
                  TextButton(onPressed: _load, child: Text(l10n.actionRetry)),
              ],
            ),
        ],
      ),
    );
  }
}

String? _metadataText(Map<String, Object?> metadata, String key) {
  final value = metadata[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
