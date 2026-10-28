/// Multi-method checkout models. The server decides availability; the app
/// only renders what `GET /v1/payments/methods` returns (CASH is always on).
library;

import '../../../l10n/app_localizations.dart';

enum PaymentGroup { wallet, card, recommended, addMore }

const paymentGroupOrder = [
  PaymentGroup.wallet,
  PaymentGroup.card,
  PaymentGroup.recommended,
  PaymentGroup.addMore,
];

String paymentGroupTitle(AppLocalizations l10n, PaymentGroup group) =>
    switch (group) {
      PaymentGroup.wallet => l10n.paymentGroupWallet,
      PaymentGroup.card => l10n.paymentGroupCard,
      PaymentGroup.recommended => l10n.paymentGroupRecommended,
      PaymentGroup.addMore => l10n.paymentGroupAddMore,
    };

PaymentGroup _groupFrom(Object? raw) => switch (raw) {
  'WALLET' => PaymentGroup.wallet,
  'CARD' => PaymentGroup.card,
  'RECOMMENDED' => PaymentGroup.recommended,
  _ => PaymentGroup.addMore,
};

const cashMethodCode = 'CASH';

class PaymentMethodOption {
  const PaymentMethodOption({
    required this.code,
    required this.label,
    required this.group,
    required this.available,
    this.subtitle,
    this.reason,
    this.requiresRedirect = false,
    this.sortOrder = 0,
  });

  factory PaymentMethodOption.fromJson(Map<String, Object?> json) {
    return PaymentMethodOption(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      group: _groupFrom(json['group']),
      available: json['available'] == true,
      reason: json['reason'] as String?,
      requiresRedirect: json['requiresRedirect'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  static const cash = PaymentMethodOption(
    code: cashMethodCode,
    // Empty label/subtitle: the UI fills them from l10n (see paymentOptionLabel).
    label: '',
    group: PaymentGroup.recommended,
    available: true,
  );

  final String code;
  final String label;
  final String? subtitle;
  final PaymentGroup group;
  final bool available;
  final String? reason;
  final bool requiresRedirect;
  final int sortOrder;

  bool get isCash => code == cashMethodCode;
}

/// Server label, or the localized cash fallback when the list never loaded.
String paymentOptionLabel(AppLocalizations l10n, PaymentMethodOption o) =>
    o.label.isEmpty && o.isCash ? l10n.paymentCashLabel : o.label;

String? paymentOptionSubtitle(AppLocalizations l10n, PaymentMethodOption o) =>
    o.label.isEmpty && o.isCash ? l10n.paymentCashSubtitle : o.subtitle;

/// Groups options in the fixed section order; guarantees CASH is present so
/// the checkout keeps working when every online method is hidden.
Map<PaymentGroup, List<PaymentMethodOption>> groupPaymentMethods(
  List<PaymentMethodOption> options,
) {
  final all = [...options];
  if (!all.any((o) => o.isCash)) {
    all.add(PaymentMethodOption.cash);
  }
  final out = <PaymentGroup, List<PaymentMethodOption>>{};
  for (final group in paymentGroupOrder) {
    final items = all.where((o) => o.group == group).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (items.isNotEmpty) {
      out[group] = items;
    }
  }
  return out;
}

/// Keeps a selection only while it is still available; otherwise falls back to CASH.
String effectivePaymentSelection(
  List<PaymentMethodOption> options,
  String? selected,
) {
  if (selected == null) return cashMethodCode;
  final hit = options.where((o) => o.code == selected && o.available);
  return hit.isEmpty ? cashMethodCode : selected;
}

/// Mirrors backend `serviceForVehicleClass`: motorbikes are BIKE, others CAR.
String paymentServiceForVehicleClass(String? code) {
  final c = (code ?? '').toUpperCase();
  return c.contains('MOTORBIKE') || c.contains('BIKE') ? 'BIKE' : 'CAR';
}

enum PaymentCheckoutStatus {
  cash,
  notStarted,
  pending,
  paid,
  failed,
  expired,
  refundPending,
  refunded,
}

PaymentCheckoutStatus paymentStatusFrom(Object? raw) => switch (raw) {
  'CASH' => PaymentCheckoutStatus.cash,
  'PENDING' => PaymentCheckoutStatus.pending,
  'PAID' => PaymentCheckoutStatus.paid,
  'FAILED' => PaymentCheckoutStatus.failed,
  'EXPIRED' => PaymentCheckoutStatus.expired,
  'REFUND_PENDING' => PaymentCheckoutStatus.refundPending,
  'REFUNDED' => PaymentCheckoutStatus.refunded,
  _ => PaymentCheckoutStatus.notStarted,
};

bool isTerminalPaymentStatus(PaymentCheckoutStatus s) =>
    s != PaymentCheckoutStatus.pending && s != PaymentCheckoutStatus.notStarted;

class PaymentCheckoutView {
  const PaymentCheckoutView({
    required this.entityType,
    required this.entityId,
    required this.methodCode,
    required this.status,
    this.amountVnd,
    this.paymentUrl,
    this.deeplink,
    this.failureReason,
  });

  factory PaymentCheckoutView.fromJson(Map<String, Object?> json) {
    return PaymentCheckoutView(
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      methodCode: json['methodCode'] as String? ?? cashMethodCode,
      status: paymentStatusFrom(json['status']),
      amountVnd: (json['amountVnd'] as num?)?.toInt(),
      paymentUrl: json['paymentUrl'] as String?,
      deeplink: json['deeplink'] as String?,
      failureReason: json['failureReason'] as String?,
    );
  }

  final String entityType;
  final String entityId;
  final String methodCode;
  final PaymentCheckoutStatus status;
  final int? amountVnd;
  final String? paymentUrl;
  final String? deeplink;
  final String? failureReason;
}

String paymentStatusTitle(AppLocalizations l10n, PaymentCheckoutStatus s) =>
    switch (s) {
      PaymentCheckoutStatus.cash => l10n.paymentStatusCash,
      PaymentCheckoutStatus.notStarted => l10n.paymentStatusNotStarted,
      PaymentCheckoutStatus.pending => l10n.paymentStatusPending,
      PaymentCheckoutStatus.paid => l10n.paymentStatusPaid,
      PaymentCheckoutStatus.failed => l10n.paymentStatusFailed,
      PaymentCheckoutStatus.expired => l10n.paymentStatusExpired,
      PaymentCheckoutStatus.refundPending => l10n.paymentStatusRefundPending,
      PaymentCheckoutStatus.refunded => l10n.paymentStatusRefunded,
    };
