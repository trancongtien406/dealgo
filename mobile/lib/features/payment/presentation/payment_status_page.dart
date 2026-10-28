import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../data/payment_api.dart';
import '../domain/payment_models.dart';
import 'payment_method_sheet.dart';

abstract final class PaymentRoutes {
  /// Matches the `dealgo://payment-return?...` deeplink (PAYMENT_APP_RETURN_URL).
  static const returnPath = '/payment-return';

  static String location({
    required String entityType,
    required String entityId,
    String? startMethod,
  }) {
    return Uri(
      path: returnPath,
      queryParameters: {
        'entityType': entityType,
        'entityId': entityId,
        'start': ?startMethod,
      },
    ).toString();
  }
}

typedef PaymentUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> defaultPaymentLauncher(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

String paymentContinueLocation(String entityType, String entityId) =>
    entityType == 'RIDE'
    ? '/customer/ride/tracking/${Uri.encodeComponent(entityId)}'
    : '/customer/food/orders/${Uri.encodeComponent(entityId)}';

/// Starts (optionally) and tracks an online payment. Polls the server; the
/// PSP IPN is the source of truth, never the redirect query string.
class PaymentStatusPage extends StatefulWidget {
  const PaymentStatusPage({
    required this.entityType,
    required this.entityId,
    this.startMethod,
    this.api,
    this.accessToken,
    this.launcher = defaultPaymentLauncher,
    this.pollInterval = const Duration(seconds: 3),
    super.key,
  });

  final String entityType;
  final String entityId;
  final String? startMethod;
  final PaymentApi? api;
  final String? accessToken;
  final PaymentUrlLauncher launcher;
  final Duration pollInterval;

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> with WidgetsBindingObserver {
  PaymentCheckoutView? _view;
  String? _error;
  var _busy = false;
  Timer? _timer;
  var _polls = 0;
  static const _maxPolls = 300;

  PaymentApi get _api => widget.api ?? defaultPaymentApi();
  String? get _token => widget.accessToken ?? paymentAccessToken(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final method = widget.startMethod;
      if (method != null && method != cashMethodCode) {
        _start(method);
      } else {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final view = _view;
    if (view == null || isTerminalPaymentStatus(view.status) || _polls >= _maxPolls) {
      return;
    }
    _timer = Timer(widget.pollInterval, () {
      _polls++;
      _refresh();
    });
  }

  Future<void> _start(String method) async {
    final token = _token;
    if (token == null) {
      setState(() => _error = 'Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final view = await _api.start(
        accessToken: token,
        entityType: widget.entityType,
        entityId: widget.entityId,
        methodCode: method,
      );
      if (!mounted) return;
      setState(() {
        _view = view;
        _busy = false;
      });
      await _openProvider(view);
      _schedule();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Không khởi tạo được thanh toán. Bạn có thể thử lại hoặc trả tiền mặt.';
      });
    }
  }

  Future<void> _refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final view = await _api.status(
        accessToken: token,
        entityType: widget.entityType,
        entityId: widget.entityId,
      );
      if (!mounted) return;
      setState(() {
        _view = view;
        _error = null;
      });
      _schedule();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error ??= 'Không tải được trạng thái thanh toán.');
      _schedule();
    }
  }

  Future<void> _openProvider(PaymentCheckoutView view) async {
    for (final raw in [view.deeplink, view.paymentUrl]) {
      final uri = raw == null ? null : Uri.tryParse(raw);
      if (uri != null && await widget.launcher(uri)) {
        return;
      }
    }
  }

  void _continue() {
    context.go(paymentContinueLocation(widget.entityType, widget.entityId));
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final status = view?.status;
    final (icon, color, surface) = switch (status) {
      PaymentCheckoutStatus.paid || PaymentCheckoutStatus.cash => (
        DealGoIcons.check,
        DealGoColors.brandGreen,
        DealGoColors.greenSurface,
      ),
      PaymentCheckoutStatus.failed || PaymentCheckoutStatus.expired => (
        DealGoIcons.error,
        DealGoColors.danger,
        DealGoColors.dangerSurface,
      ),
      PaymentCheckoutStatus.refundPending || PaymentCheckoutStatus.refunded => (
        DealGoIcons.refresh,
        DealGoColors.info,
        DealGoColors.infoSurface,
      ),
      _ => (DealGoIcons.clock, DealGoColors.warning, DealGoColors.warningSurface),
    };
    final retryable =
        status == PaymentCheckoutStatus.failed || status == PaymentCheckoutStatus.expired;
    final pending = status == PaymentCheckoutStatus.pending;
    final method = view?.methodCode ?? widget.startMethod;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: 'Thanh toán', onBack: _continue),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                children: [
                  const SizedBox(height: DealGoSpacing.s24),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
                      child: _busy || view == null
                          ? const Padding(
                              padding: EdgeInsets.all(DealGoSpacing.s20),
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Icon(icon, color: color, size: 36),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text(
                    key: const Key('payment-status-title'),
                    view == null ? 'Đang chuẩn bị thanh toán…' : paymentStatusTitle(view.status),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: DealGoColors.text,
                    ),
                  ),
                  if (pending)
                    const Padding(
                      padding: EdgeInsets.only(top: DealGoSpacing.s8),
                      child: Text(
                        'Hoàn tất thanh toán trong ứng dụng ví/ngân hàng rồi quay lại DealGo. '
                        'Trạng thái tự cập nhật.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DealGoColors.textSecondary),
                      ),
                    ),
                  if (view?.failureReason case final reason? when retryable)
                    Padding(
                      padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                      child: Text(
                        reason,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: DealGoColors.textSecondary),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: DealGoSpacing.s12),
                      child: Text(
                        _error!,
                        key: const Key('payment-status-error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: DealGoColors.danger),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pending && view != null) ...[
                    DealGoSecondaryButton(
                      label: 'Mở lại trang thanh toán',
                      onPressed: () => _openProvider(view),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  if ((retryable || (_error != null && view == null)) && method != null) ...[
                    DealGoSecondaryButton(
                      label: 'Thử lại',
                      onPressed: () => _start(method),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DealGoSecondaryButton(
                      label: 'Chuyển sang tiền mặt',
                      onPressed: () => _start(cashMethodCode),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  DealGoPrimaryButton(
                    label: 'Tiếp tục',
                    isLoading: _busy,
                    onPressed: _continue,
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
