import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';

/// C014 — in-trip safety center (UI only; no fake SOS backend).
class RideSafetyPage extends StatefulWidget {
  const RideSafetyPage({required this.rideId, super.key});

  final String rideId;

  @override
  State<RideSafetyPage> createState() => _RideSafetyPageState();
}

class _RideSafetyPageState extends State<RideSafetyPage> {
  var _shareCopied = false;
  final _contacts = <_EmergencyContact>[
    const _EmergencyContact(name: 'Minh Anh', phone: '0901 234 567'),
    const _EmergencyContact(name: 'Gia đình', phone: '0902 345 678'),
  ];

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RideRoutes.tracking(widget.rideId));
  }

  Future<void> _shareTrip() async {
    final link = 'https://dealgo.app/t/${widget.rideId}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    setState(() => _shareCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).rideSafetyShareCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(title: l10n.rideSafetyTitle, onBack: _back),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  DealGoBanner(
                    tone: DealGoBannerTone.info,
                    title: l10n.rideSafetyBannerTitle,
                    message: l10n.rideSafetyBannerBody,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.rideSafetyShareTitle,
                                style: textTheme.titleMedium,
                              ),
                            ),
                            if (_shareCopied)
                              DealGoChip(
                                label: l10n.commonSelected,
                                tone: DealGoChipTone.success,
                              ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Text(
                          l10n.rideSafetyShareBody,
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        DealGoPrimaryButton(
                          key: const Key('ride-safety-share'),
                          label: l10n.rideSafetyShareCta,
                          onPressed: _shareTrip,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.rideSafetyContactsTitle,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Text(
                          l10n.rideSafetyContactsBody,
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        for (final contact in _contacts) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: DealGoColors.subtlePurple,
                              child: Text(
                                contact.name.substring(0, 1),
                                style: const TextStyle(
                                  color: DealGoColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(contact.name),
                            subtitle: Text(contact.phone),
                            trailing: DealGoChip(
                              label: l10n.rideSafetyContactLocal,
                              tone: DealGoChipTone.neutral,
                            ),
                          ),
                        ],
                        DealGoSecondaryButton(
                          key: const Key('ride-safety-add-contact'),
                          label: l10n.rideSafetyAddContact,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.rideSafetyContactsMockHint),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoBanner(
                    tone: DealGoBannerTone.warning,
                    title: l10n.rideSafetyEmergencyTitle,
                    message: l10n.rideSafetyEmergencyBody,
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

class _EmergencyContact {
  const _EmergencyContact({required this.name, required this.phone});

  final String name;
  final String phone;
}
