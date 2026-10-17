import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/list_food_order_chat_messages.dart';
import '../../domain/usecases/list_ride_chat_messages.dart';
import '../../domain/usecases/send_food_order_chat_message.dart';
import '../../domain/usecases/send_ride_chat_message.dart';
import '../cubit/chat_cubit.dart';

Future<void> showTransactionChatSheet({
  required BuildContext context,
  required ChatThreadKind kind,
  required String resourceId,
  required String? accessToken,
  String? currentUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DealGoColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => ChatCubit(
          listRideChatMessages: context.read<ListRideChatMessages>(),
          sendRideChatMessage: context.read<SendRideChatMessage>(),
          listFoodOrderChatMessages: context.read<ListFoodOrderChatMessages>(),
          sendFoodOrderChatMessage: context.read<SendFoodOrderChatMessage>(),
          kind: kind,
          resourceId: resourceId,
        )..load(accessToken: accessToken),
        child: TransactionChatSheet(
          accessToken: accessToken,
          currentUserId: currentUserId,
        ),
      );
    },
  );
}

class TransactionChatSheet extends StatefulWidget {
  const TransactionChatSheet({
    required this.accessToken,
    this.currentUserId,
    super.key,
  });

  final String? accessToken;
  final String? currentUserId;

  @override
  State<TransactionChatSheet> createState() => _TransactionChatSheetState();
}

class _TransactionChatSheetState extends State<TransactionChatSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text;
    await context.read<ChatCubit>().send(
      accessToken: widget.accessToken,
      body: body,
    );
    if (!mounted) {
      return;
    }
    if (context.read<ChatCubit>().state.sendError == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DealGoColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.chatTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<ChatCubit, ChatState>(
                listenWhen: (previous, current) =>
                    previous.sendError != current.sendError &&
                    current.sendError != null,
                listener: (context, state) {
                  final message = localizedFailureMessage(
                    context,
                    state.sendError!,
                  );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                  context.read<ChatCubit>().clearSendError();
                },
                builder: (context, state) {
                  if (state.loading && state.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.loadError != null && state.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            localizedFailureMessage(
                              context,
                              state.loadError!,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.read<ChatCubit>().load(
                              accessToken: widget.accessToken,
                            ),
                            child: Text(l10n.actionRetry),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state.messages.isEmpty) {
                    return Center(child: Text(l10n.chatEmpty));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final mine =
                          widget.currentUserId != null &&
                          message.senderUserId == widget.currentUserId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? DealGoColors.subtlePurple
                                : DealGoColors.canvas,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message.body,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: l10n.chatInputHint,
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BlocBuilder<ChatCubit, ChatState>(
                      builder: (context, state) {
                        return IconButton.filled(
                          onPressed: state.sending ? null : _send,
                          icon: state.sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
