import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/navigation/external_navigator.dart';
import '../../../../l10n/app_localizations.dart';

/// "Open in Google Maps / Waze" for the current stop (DEC-PROD-035).
///
/// Uses the native app when installed, else the web link; when nothing opens
/// the driver gets a snackbar instead of a silent no-op.
class DriverNavigateButtons extends StatelessWidget {
  const DriverNavigateButtons({
    required this.lat,
    required this.lng,
    super.key,
  });

  final double lat;
  final double lng;

  Future<void> _open(BuildContext context, NavigationApp app) async {
    final navigator = context.read<ExternalNavigator>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).driverNavOpenFailed;
    final opened = await navigator.open(app, lat: lat, lng: lng);
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const Key('driver-nav-buttons'),
      children: [
        Expanded(
          child: DealGoSecondaryButton(
            key: const Key('driver-nav-google'),
            label: l10n.driverNavGoogleMaps,
            leadingIcon: DealGoIcons.navigation,
            onPressed: () => _open(context, NavigationApp.googleMaps),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(
          child: DealGoSecondaryButton(
            key: const Key('driver-nav-waze'),
            label: l10n.driverNavWaze,
            leadingIcon: DealGoIcons.map,
            onPressed: () => _open(context, NavigationApp.waze),
          ),
        ),
      ],
    );
  }
}
