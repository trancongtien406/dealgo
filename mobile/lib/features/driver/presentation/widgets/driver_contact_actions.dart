import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/components/dealgo_contact_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/cubit/chat_cubit.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../chat/presentation/widgets/transaction_chat_sheet.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../voice/domain/entities/voice_models.dart';
import '../../../voice/presentation/widgets/voice_call_actions.dart';
import 'driver_widgets.dart';
import '../../../chat/presentation/widgets/open_chat_on_arrival.dart';

/// Call + chat buttons for the customer of an assigned ride / food order.
class DriverContactActions extends StatelessWidget {
  const DriverContactActions({
    required this.resourceId,
    this.isFood = false,
    super.key,
  });

  final String resourceId;
  final bool isFood;

  void _chat(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    showTransactionChatSheet(
      context: context,
      kind: isFood ? ChatThreadKind.foodOrder : ChatThreadKind.ride,
      resourceId: resourceId,
      accessToken: driverAccessToken(context),
      currentUserId: auth is AuthSignedIn ? auth.profile.id : null,
      viewer: ChatViewer.driver,
      onCall: voiceCallsEnabled(context, listen: false)
          ? () => _call(context)
          : null,
    );
  }

  void _call(BuildContext context) {
    startVoiceCall(
      context,
      kind: isFood ? VoiceThreadKind.foodOrder : VoiceThreadKind.ride,
      resourceId: resourceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OpenChatOnArrival(
      onOpen: () => _chat(context),
      child: DealGoContactActions(
        children: [
          if (voiceCallsEnabled(context))
            DealGoContactButton(
              key: const Key('driver-contact-call'),
              tooltip: l10n.driverCallCustomer,
              onPressed: () => _call(context),
              filled: true,
              color: DealGoColors.brandGreen,
              icon: const Icon(DealGoIcons.phone),
            ),
          DealGoContactButton(
            key: const Key('driver-contact-chat'),
            tooltip: l10n.driverChatCustomer,
            onPressed: () => _chat(context),
            icon: ChatUnreadBadge(
              aggregateType: isFood ? 'FoodOrder' : 'Ride',
              aggregateId: resourceId,
              child: const Icon(DealGoIcons.chat),
            ),
          ),
        ],
      ),
    );
  }
}
