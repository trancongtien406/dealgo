import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/ride_share.dart';

import '../../data/emergency_contacts_store.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_dialog.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

/// C014 — in-trip safety center (UI only; no fake SOS backend).
class RideSafetyPage extends StatefulWidget {
  const RideSafetyPage({required this.rideId, super.key});

  final String rideId;

  @override
  State<RideSafetyPage> createState() => _RideSafetyPageState();
}

class _RideSafetyPageState extends State<RideSafetyPage> {
  var _shareCopied = false;
  var _sharing = false;
  List<EmergencyContact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    EmergencyContactsStore.load().then((contacts) {
      if (mounted) setState(() => _contacts = contacts);
    });
  }

  Future<void> _addContact() async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    final phone = TextEditingController();
    final saved = await showDealGoDialog<bool>(
      context: context,
      title: l10n.rideSafetyAddContact,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DealGoTextField(
            label: l10n.rideSafetyContactName,
            controller: name,
            fieldKey: const Key('ride-safety-contact-name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoTextField(
            label: l10n.rideSafetyContactPhone,
            controller: phone,
            fieldKey: const Key('ride-safety-contact-phone'),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      primaryLabel: l10n.actionSave,
      secondaryLabel: l10n.actionCancel,
      primaryKey: const Key('ride-safety-contact-save'),
    );
    final n = name.text.trim();
    final p = phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      phone.dispose();
    });
    if (saved != true || n.isEmpty || p.length < 9) return;
    final next = await EmergencyContactsStore.add(
      EmergencyContact(name: n, phone: p),
    );
    if (mounted) setState(() => _contacts = next);
  }

  Future<void> _removeContact(EmergencyContact contact) async {
    final next = await EmergencyContactsStore.remove(contact.phone);
    if (mounted) setState(() => _contacts = next);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RideRoutes.tracking(widget.rideId));
  }

  Future<void> _shareTrip() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthCubit>().state;
    if (_sharing || auth is! AuthSignedIn) return;
    setState(() => _sharing = true);
    try {
      final link = await context.read<RideShareRepository>().create(
        accessToken: auth.tokens.accessToken,
        rideId: widget.rideId,
      );
      await Clipboard.setData(ClipboardData(text: link.url));
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _shareCopied = true;
      });
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rideSafetyShareCopied)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _sharing = false);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (error.errorCode) {
            'RIDE_SHARE_NOT_ACTIVE' => l10n.rideShareNotActive,
            'RIDE_SHARE_LIMIT' => l10n.rideShareLimit,
            _ => l10n.rideShareFailed,
          }),
        ),
      );
    }
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
            DealGoAppHeader(title: l10n.rideSafetyTitle, onBack: _back),
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
                                label: l10n.rideShareCopiedChip,
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
                          isLoading: _sharing,
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
                            trailing: IconButton(
                              tooltip: l10n.rideSafetyRemoveContact,
                              icon: const Icon(DealGoIcons.close),
                              onPressed: () => _removeContact(contact),
                            ),
                          ),
                        ],
                        if (_contacts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: DealGoSpacing.s8,
                            ),
                            child: Text(
                              l10n.rideSafetyContactsEmpty,
                              key: const Key('ride-safety-contacts-empty'),
                              style: textTheme.bodySmall,
                            ),
                          ),
                        DealGoSecondaryButton(
                          key: const Key('ride-safety-add-contact'),
                          label: l10n.rideSafetyAddContact,
                          onPressed: () {
                            if (_contacts.length <
                                EmergencyContactsStore.maxContacts) {
                              _addContact();
                            }
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
