import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/voice_models.dart';
import '../../domain/usecases/create_food_order_voice_session.dart';
import '../../domain/usecases/create_ride_voice_session.dart';
import '../cubit/voice_cubit.dart';

Future<void> showVoiceCallSheet({
  required BuildContext context,
  required VoiceThreadKind kind,
  required String resourceId,
  required String? accessToken,
}) {
  return showDealGoSheet<void>(
    context: context,
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => VoiceCubit(
          createRideVoiceSession: context.read<CreateRideVoiceSession>(),
          createFoodOrderVoiceSession: context
              .read<CreateFoodOrderVoiceSession>(),
          kind: kind,
          resourceId: resourceId,
        )..start(accessToken: accessToken),
        child: const VoiceCallSheet(),
      );
    },
  );
}

/// LiveKit join is stubbed: shows room name + token URL after fetch.
/// Wire `livekit_client` when LIVEKIT_* keys are filled (ADR-006).
class VoiceCallSheet extends StatelessWidget {
  const VoiceCallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        child: BlocBuilder<VoiceCubit, VoiceState>(
          builder: (context, state) {
            return switch (state) {
              VoiceInitial() || VoiceLoading() => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              VoiceFailure(:final message) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.voiceTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(message.resolve(l10n), style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: DealGoSpacing.s16),
                  DealGoPrimaryButton(
                    key: const Key('voice-dismiss'),
                    label: l10n.actionCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              VoiceReady(:final session) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.voiceTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    l10n.voiceStubHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    '${l10n.voiceRoomLabel}: ${session.roomName}',
                    key: const Key('voice-room-name'),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (session.url != null) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      session.url!,
                      key: const Key('voice-room-url'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: DealGoSpacing.s16),
                  DealGoPrimaryButton(
                    key: const Key('voice-dismiss'),
                    label: l10n.actionCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            };
          },
        ),
      ),
    );
  }
}
