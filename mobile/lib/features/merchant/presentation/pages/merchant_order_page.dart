import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../utils/merchant_kitchen_lines.dart';
import '../widgets/merchant_kitchen_line_row.dart';
import '../widgets/merchant_order_change_sheet.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../domain/usecases/accept_merchant_order.dart';
import '../../domain/usecases/get_merchant_order.dart';
import '../../domain/usecases/mark_merchant_order_ready.dart';
import '../../domain/usecases/reject_merchant_order.dart';
import '../../../food/presentation/widgets/food_order_extras.dart';
import '../../../food/presentation/widgets/food_reject_reason.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../cubit/merchant_order_cubit.dart';
import '../cubit/merchant_queue_cubit.dart';
import '../cubit/merchant_states.dart';
import '../widgets/merchant_widgets.dart';
import '../../../chat/presentation/cubit/chat_cubit.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../chat/presentation/widgets/open_chat_on_arrival.dart';
import '../../../chat/presentation/widgets/transaction_chat_sheet.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../../core/design_system/components/handover_ref_badge.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';

class MerchantMissingOrderPage extends StatelessWidget {
  const MerchantMissingOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: MerchantPageFrame(
        title: l10n.merchantOrderTitle,
        insetBottom: true,
        body: Center(child: Text(l10n.merchantOrderNotFound)),
      ),
    );
  }
}

class MerchantOrderPage extends StatelessWidget {
  const MerchantOrderPage({required this.order, super.key});

  final MerchantQueueOrder order;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final auth = context.read<AuthCubit>();
        return MerchantOrderCubit(
            getMerchantOrder: context.read<GetMerchantOrder>(),
            acceptMerchantOrder: context.read<AcceptMerchantOrder>(),
            markMerchantOrderReady: context.read<MarkMerchantOrderReady>(),
            rejectMerchantOrder: context.read<RejectMerchantOrder>(),
            queue: context.read<MerchantQueueCubit>(),
            order: order,
            realtime: context.read<SnapshotRealtime>(),
          )
          ..loadLines(merchantAccessToken(context))
          ..startAutoRefresh(() {
            final s = auth.state;
            return s is AuthSignedIn ? s.tokens.accessToken : null;
          });
      },
      child: const _MerchantOrderView(),
    );
  }
}

class _MerchantOrderView extends StatelessWidget {
  const _MerchantOrderView();

  @override
  Widget build(BuildContext context) {
    final view = context.watch<MerchantOrderCubit>().state;
    if (view is! MerchantOrderViewReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final queue = context.watch<MerchantQueueCubit>().state;
    final cubit = context.read<MerchantOrderCubit>();
    if (view.network) {
      final saved = queue is MerchantQueueReady
          ? queue.orders
          : <MerchantQueueOrder>[view.order];
      final syncedAt = queue is MerchantQueueFailed ? queue.syncedAt : null;
      return Scaffold(
        body: MerchantQueueErrorView(
          saved: saved,
          syncedAt: syncedAt,
          // Network banner is offline-only; pass a stable cause so copy matches.
          cause: const ApiException(
            statusCode: 0,
            message: '',
            errorCode: 'NETWORK_ERROR',
          ),
          onRetry: () {
            cubit.clearNetworkBanner();
            cubit.reload(merchantAccessToken(context));
          },
        ),
      );
    }
    if (view.conflict) {
      return Scaffold(
        body: _Conflict(
          order: view.order,
          onReload: () => cubit.reload(merchantAccessToken(context)),
        ),
      );
    }
    return Scaffold(
      body: _Detail(
        order: view.order,
        kitchenLines: view.kitchenLines,
        busy: view.busy,
        message: view.message?.resolve(AppLocalizations.of(context)),
        handoffDone: view.handoffDone,
        handoverCode: view.handoverCode,
        pendingChange: view.pendingChange,
        orderNote: view.orderNote,
        utensils: view.utensils,
        onEditOrder: () async {
          final change = await showMerchantOrderChangeSheet(
            context,
            orderId: view.order.id,
            lines: view.kitchenLines,
          );
          if (change != null && context.mounted) {
            await cubit.changeProposed(change, merchantAccessToken(context));
          }
        },
        onAccept: () => cubit.accept(merchantAccessToken(context)),
        onReject: (reason, note) => cubit.reject(
          merchantAccessToken(context),
          reason: reason,
          note: note,
        ),
        onReady: () => cubit.markReady(merchantAccessToken(context)),
        onHandoff: () => cubit.confirmHandoff(merchantAccessToken(context)),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.order,
    required this.kitchenLines,
    required this.busy,
    required this.message,
    required this.handoffDone,
    required this.onAccept,
    this.handoverCode,
    this.pendingChange,
    this.orderNote,
    this.utensils = true,
    required this.onEditOrder,
    required this.onReject,
    required this.onReady,
    required this.onHandoff,
  });

  final MerchantQueueOrder order;
  final List<MerchantKitchenLine> kitchenLines;
  final bool busy;
  final String? message;
  final bool handoffDone;
  final String? handoverCode;
  final FoodOrderChange? pendingChange;
  final String? orderNote;
  final bool utensils;
  final VoidCallback onEditOrder;
  final VoidCallback onAccept;
  final Future<bool> Function(FoodRejectReason reason, String? note) onReject;
  final VoidCallback onReady;
  final VoidCallback onHandoff;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // ASSIGNED = a driver claimed the ready order and is coming to collect it.
    final ready =
        order.status == 'READY' ||
        order.status == 'READY_FOR_PICKUP' ||
        order.status == 'ASSIGNED';
    final preparing = order.status == 'PREPARING';
    final l10n = AppLocalizations.of(context);
    final isPlaced = order.status == 'PLACED';
    final title = switch (order.status) {
      'PLACED' => l10n.merchantOrderTitleNew,
      'PREPARING' => l10n.merchantOrderTitlePreparing,
      'READY' ||
      'READY_FOR_PICKUP' ||
      'ASSIGNED' => l10n.merchantOrderTitleReady,
      _ => l10n.merchantOrderTitle,
    };
    final lines = kitchenLines;
    final placedAt = DateTime.tryParse(order.createdAt)?.toLocal();
    final Widget? footer;
    if (isPlaced) {
      footer = MerchantFooter(
        secondaryLabel: l10n.merchantRejectOrder,
        primaryLabel: l10n.merchantAcceptOrder,
        primaryKey: const Key('merchant-accept'),
        primaryEnabled: !busy,
        primaryLoading: busy,
        onSecondary: () => _confirmReject(context),
        onPrimary: onAccept,
      );
    } else if (preparing) {
      footer = MerchantPrimaryBar(
        label: l10n.merchantMarkReady,
        buttonKey: const Key('merchant-ready'),
        enabled: !busy && pendingChange == null,
        loading: busy,
        onPressed: onReady,
      );
    } else if (ready && !handoffDone) {
      footer = MerchantPrimaryBar(
        label: l10n.merchantMarkHandedOver,
        buttonKey: const Key('merchant-handoff'),
        // QA M1 — nothing to hand over until a driver has claimed the order.
        enabled: !busy && order.status == 'ASSIGNED',
        loading: busy,
        onPressed: onHandoff,
      );
    } else {
      footer = null;
    }
    final page = MerchantPageFrame(
      title: title,
      insetBottom: true,
      onBack: () => merchantBack(context),
      footer: footer,
      body: ListView(
        padding: dealGoScrollPadding(context, merchantPagePadding),
        children: [
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (order.status) {
                  'PLACED' => l10n.merchantOrderHeadNew,
                  'PREPARING' => l10n.merchantOrderHeadPreparing,
                  'READY' || 'READY_FOR_PICKUP' => l10n.merchantOrderHeadReady,
                  _ => l10n.merchantOrderTitle,
                }, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: DealGoSpacing.s8,
                  runSpacing: DealGoSpacing.s8,
                  children: [
                    // QA M5: the badge is the single order ref on this card.
                    HandoverRefBadge(orderId: order.id, dense: true),
                    if (placedAt != null)
                      MerchantChip(
                        label: l10n.merchantOrderPlacedAt(
                          DateFormat('HH:mm · dd/MM').format(placedAt),
                        ),
                        tone: MerchantChipTone.neutral,
                      ),
                  ],
                ),
                if (isPlaced) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: DealGoColors.subtlePurple,
                        child: Icon(
                          DealGoIcons.user,
                          color: DealGoColors.primary,
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName ?? l10n.merchantOrderCustomer,
                              style: textTheme.titleMedium,
                            ),
                            Text(
                              order.dropoff.label,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  MerchantChip(
                    label: l10n.merchantOrderNewChip,
                    tone: MerchantChipTone.warning,
                  ),
                ] else ...[
                  const SizedBox(height: DealGoSpacing.s8),
                  Wrap(
                    spacing: DealGoSpacing.s8,
                    runSpacing: DealGoSpacing.s8,
                    children: [
                      MerchantChip(
                        label: merchantStatusLabel(l10n, order.status),
                        tone: merchantStatusTone(order.status),
                      ),
                      if (order.customerName case final name?)
                        MerchantChip(
                          label: l10n.merchantOrderCustomerName(name),
                          tone: MerchantChipTone.neutral,
                        ),
                      if (order.driverName case final name?)
                        MerchantChip(
                          label: l10n.merchantOrderDriverName(name),
                          tone: MerchantChipTone.green,
                        ),
                    ],
                  ),
                ],
                if (merchantCanChat(order.status)) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  OutlinedButton.icon(
                    key: const Key('merchant-open-chat'),
                    onPressed: () => openMerchantCustomerChat(context, order),
                    icon: ChatUnreadBadge(
                      aggregateType: 'FoodOrderShop',
                      aggregateId: order.id,
                      child: const Icon(DealGoIcons.chat, size: 18),
                    ),
                    label: Text(l10n.chatContactCustomer),
                  ),
                ],
              ],
            ),
          ),
          if (isPlaced) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.merchantOrderItemsTitle,
                    style: textTheme.titleMedium,
                  ),
                  for (final line in lines) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    MerchantKitchenLineRow(line: line),
                  ],
                ],
              ),
            ),
          ],
          if ((isPlaced || preparing) &&
              ((orderNote ?? '').trim().isNotEmpty || !utensils)) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: FoodOrderExtrasBlock(note: orderNote, utensils: utensils),
            ),
          ],
          if (preparing) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.merchantItemsToPrepare,
                    style: textTheme.titleMedium,
                  ),
                  for (final line in lines) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    MerchantKitchenLineRow(line: line),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantNote(
              tone: MerchantNoteTone.green,
              message: l10n.merchantReadyHint,
            ),
          ],
          if (ready) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.merchantDriverTitle, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  Row(
                    children: [
                      const Icon(
                        DealGoIcons.motorbike,
                        color: DealGoColors.primary,
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Text(
                          // Masked by the server once a driver has claimed it.
                          order.driverName ?? l10n.merchantDriverWaiting,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              color: DealGoColors.subtlePurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.merchantHandoffTitle, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  if (handoverCode case final code?) ...[
                    Row(
                      key: const Key('merchant-handover-code-row'),
                      children: [
                        Expanded(
                          child: Text(
                            l10n.merchantHandoverCodeLabel,
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          code,
                          key: const Key('merchant-handover-code'),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      l10n.merchantHandoverCodeHint,
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  MerchantMoneyRow(
                    label: l10n.merchantOrderRefLabel,
                    value: shortRef(order.id),
                    emphasize: true,
                  ),
                  MerchantMoneyRow(
                    label: l10n.merchantLineCountLabel,
                    value: '${order.lineCount}',
                  ),
                  MerchantMoneyRow(
                    label: l10n.merchantHandoffCodLabel,
                    value: formatVnd(order.subtotalVnd),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantNote(
              tone: MerchantNoteTone.green,
              message: handoffDone
                  ? l10n.merchantHandoffDoneNote
                  : l10n.merchantHandoffNote,
            ),
          ],
          if (!preparing) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.merchantOrderValueTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  MerchantMoneyRow(
                    label: l10n.merchantFoodValueLabel,
                    value: formatVnd(order.subtotalVnd),
                  ),
                  MerchantMoneyRow(
                    label: merchantDeliveryFeeLabel(l10n, order.status),
                    value: formatVnd(order.deliveryFareVnd),
                  ),
                  MerchantMoneyRow(
                    label: l10n.merchantOrderDiscount,
                    value: formatVnd(0),
                  ),
                  const Divider(height: DealGoSpacing.s24),
                  MerchantMoneyRow(
                    label: l10n.merchantOrderCodTotal,
                    value: formatVnd(order.totalVnd),
                    emphasize: true,
                  ),
                  MerchantMoneyRow(
                    label: l10n.merchantOrderFoodRevenue,
                    value: formatVnd(order.subtotalVnd),
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ],
          if (isPlaced || preparing) ...[
            const SizedBox(height: DealGoSpacing.s12),
            if (pendingChange case final change?)
              MerchantNote(
                key: const Key('merchant-change-pending'),
                message: l10n.merchantChangePending(
                  formatVnd(change.newTotalVnd),
                  DateFormat('HH:mm').format(change.expiresAt.toLocal()),
                ),
              )
            else if (lines.any((line) => line.id != null))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('merchant-edit-order'),
                  onPressed: busy ? null : onEditOrder,
                  icon: const Icon(DealGoIcons.edit),
                  label: Text(l10n.merchantEditOrder),
                ),
              ),
          ],
          if (message != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantNote(message: message!),
          ],
        ],
      ),
    );
    // Merchant push links use `?chat=1`; this page only hosts the shop thread.
    return OpenChatOnArrival(
      onOpen: () {
        if (merchantCanChat(order.status)) {
          openMerchantCustomerChat(context, order);
        }
      },
      child: page,
    );
  }

  Future<void> _confirmReject(BuildContext context) async {
    final choice = await showDialog<({FoodRejectReason reason, String? note})>(
      context: context,
      builder: (context) => const MerchantRejectDialog(),
    );
    if (choice == null || !context.mounted) {
      return;
    }
    final rejected = await onReject(choice.reason, choice.note);
    if (!rejected || !context.mounted) {
      return;
    }
    _leaveDeclinedOrder(context);
  }
}

void _leaveDeclinedOrder(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l10n.merchantRejectDone)));
  merchantReturnToOrders(context);
}

class _Conflict extends StatelessWidget {
  const _Conflict({required this.order, required this.onReload});

  final MerchantQueueOrder order;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return MerchantPageFrame(
      title: l10n.merchantConflictTitle,
      insetBottom: true,
      onBack: () => merchantBack(context),
      footer: MerchantFooter(
        secondaryLabel: l10n.merchantBackToOrders,
        primaryLabel: l10n.merchantConflictRefresh,
        primaryKey: const Key('merchant-refresh-conflict'),
        onSecondary: () => merchantBack(context),
        onPrimary: () => onReload(),
      ),
      body: ListView(
        padding: dealGoScrollPadding(context, merchantPagePadding),
        children: [
          MerchantHero(
            icon: DealGoIcons.swapHoriz,
            iconColor: DealGoColors.amber,
            background: DealGoColors.amberSurface,
            title: l10n.merchantConflictHeadline,
            message: l10n.merchantConflictBody,
          ),
          const SizedBox(height: DealGoSpacing.s24),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.merchantConflictOrder, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                MerchantMoneyRow(
                  label: l10n.merchantOrderRefLabel,
                  value: shortRef(order.id),
                ),
                MerchantMoneyRow(
                  label: l10n.merchantFoodValueLabel,
                  value: formatVnd(order.subtotalVnd),
                ),
                MerchantMoneyRow(
                  label: merchantDeliveryFeeLabel(l10n, order.status),
                  value: formatVnd(order.deliveryFareVnd),
                ),
                MerchantMoneyRow(
                  label: l10n.merchantTotalLabel,
                  value: formatVnd(order.totalVnd),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reason picker shown before a store declines an order (DEC-PROD-021).
class MerchantRejectDialog extends StatefulWidget {
  const MerchantRejectDialog({super.key});

  @override
  State<MerchantRejectDialog> createState() => _MerchantRejectDialogState();
}

class _MerchantRejectDialogState extends State<MerchantRejectDialog> {
  FoodRejectReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid {
    final reason = _reason;
    if (reason == null) return false;
    return reason != FoodRejectReason.other || _note.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(l10n.merchantRejectConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.merchantRejectConfirmBody, style: textTheme.bodySmall),
            const SizedBox(height: DealGoSpacing.s8),
            Text(l10n.merchantRejectReasonTitle, style: textTheme.labelLarge),
            RadioGroup<FoodRejectReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in FoodRejectReason.storeChoices)
                    RadioListTile<FoodRejectReason>(
                      key: Key('merchant-reject-reason-${reason.wire}'),
                      value: reason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(foodRejectReasonLabel(l10n, reason)),
                    ),
                ],
              ),
            ),
            DealGoTextField(
              label: _reason == FoodRejectReason.other
                  ? l10n.merchantRejectNoteRequired
                  : l10n.merchantRejectNoteOptional,
              controller: _note,
              fieldKey: const Key('merchant-reject-note'),
              maxLength: foodRejectNoteMax,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('merchant-reject-keep'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.merchantRejectKeep),
        ),
        TextButton(
          key: const Key('merchant-reject-confirm'),
          onPressed: _valid
              ? () {
                  final note = _note.text.trim();
                  Navigator.of(
                    context,
                  ).pop((reason: _reason!, note: note.isEmpty ? null : note));
                }
              : null,
          child: Text(l10n.merchantRejectConfirmCta),
        ),
      ],
    );
  }
}

/// The shop ↔ customer thread is open while the order is live (not after
/// delivery / cancellation / rejection).
bool merchantCanChat(String status) => const {
  'PLACED',
  'PREPARING',
  'READY',
  'READY_FOR_PICKUP',
  'ASSIGNED',
  'PICKED_UP',
}.contains(status);

/// Merchant side of the food order's customer ↔ shop thread. Never the
/// customer ↔ driver thread: the server refuses that one for the merchant.
void openMerchantCustomerChat(BuildContext context, MerchantQueueOrder order) {
  final auth = context.read<AuthCubit>().state;
  final name = order.customerName?.trim() ?? '';
  showTransactionChatSheet(
    context: context,
    kind: ChatThreadKind.foodOrderShop,
    resourceId: order.id,
    accessToken: merchantAccessToken(context),
    currentUserId: auth is AuthSignedIn ? auth.profile.id : null,
    viewer: ChatViewer.merchant,
    counterpart: name.isEmpty ? null : ChatCounterpart(name: name),
  );
}

/// Once a driver is assigned the delivery fee is the one agreed between the
/// customer and the driver; before that it is only the customer's offer.
String merchantDeliveryFeeLabel(AppLocalizations l10n, String status) =>
    const {'ASSIGNED', 'PICKED_UP', 'DELIVERED'}.contains(status)
    ? l10n.merchantFareAgreed
    : l10n.merchantDeliveryFeeLabel;
