import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../widgets/merchant_widgets.dart';

class MerchantQueueLoadingView extends StatelessWidget {
  const MerchantQueueLoadingView({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return MerchantPageFrame(
      title: title,
      onBack: () => merchantBack(context),
      body: const Center(child: Text('Đang tải đơn hàng')),
    );
  }
}

class MerchantIneligibleView extends StatelessWidget {
  const MerchantIneligibleView({
    required this.title,
    required this.onRetry,
    super.key,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MerchantPageFrame(
      title: title,
      subtitle: merchantStateSubtitle,
      onBack: () => merchantBack(context),
      footer: MerchantPrimaryBar(
        buttonKey: const Key('merchant-retry-queue'),
        label: AppLocalizations.of(context).actionRetry,
        onPressed: onRetry,
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: const [
          MerchantHero(
            icon: Icons.priority_high,
            iconColor: DealGoColors.danger,
            background: DealGoColors.dangerSurface,
            title: 'Cửa hàng chưa được phép nhận đơn',
            message: 'Máy chủ từ chối hàng đợi vì vai trò cửa hàng chưa hoạt động. Đây không phải hàng đợi trống.',
          ),
          SizedBox(height: DealGoSpacing.s16),
          MerchantNote(
            message: 'Không có bước tải hồ sơ trên màn này. Quyền nhận đơn do máy chủ quyết định.',
          ),
        ],
      ),
    );
  }
}

class MerchantQueueEmptyView extends StatelessWidget {
  const MerchantQueueEmptyView({required this.onCheck, super.key});

  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MerchantPageFrame(
      title: 'Đơn hàng của Shop',
      subtitle: merchantStateSubtitle,
      onBack: () => merchantBack(context),
      footer: MerchantPrimaryBar(
        buttonKey: const Key('merchant-check-orders'),
        label: 'Kiểm tra cài đặt nhận đơn',
        onPressed: onCheck,
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          const MerchantHero(
            icon: Icons.crop_square_rounded,
            iconColor: DealGoColors.brandGreen,
            background: DealGoColors.greenSurface,
            title: 'Chưa có đơn mới',
            message: 'Cửa hàng đang mở và sẵn sàng nhận đơn. Đơn mới sẽ xuất hiện tại đây.',
          ),
          const SizedBox(height: DealGoSpacing.s24),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trạng thái cửa hàng', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                const MerchantChip(
                  label: 'Đang mở',
                  tone: MerchantChipTone.green,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                const MerchantMoneyRow(
                  label: 'Chế độ nhận đơn',
                  value: 'Tự động / thủ công',
                ),
                const MerchantMoneyRow(label: 'Đơn chờ xác nhận', value: '0'),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const MerchantNote(
            message: 'Empty khác với lỗi tải đơn. Có thể bật thông báo để không bỏ lỡ đơn mới.',
          ),
        ],
      ),
    );
  }
}

class MerchantQueueErrorView extends StatefulWidget {
  const MerchantQueueErrorView({
    required this.saved,
    required this.syncedAt,
    required this.onRetry,
    super.key,
  });

  final List<MerchantQueueOrder> saved;
  final DateTime? syncedAt;
  final VoidCallback onRetry;

  @override
  State<MerchantQueueErrorView> createState() => _MerchantQueueErrorViewState();
}

class _MerchantQueueErrorViewState extends State<MerchantQueueErrorView> {
  var _showSaved = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MerchantPageFrame(
      title: 'Đơn hàng của Shop',
      subtitle: merchantStateSubtitle,
      onBack: () => merchantBack(context),
      footer: MerchantFooter(
        secondaryLabel: 'Xem đơn đã lưu',
        primaryLabel: AppLocalizations.of(context).actionRetry,
        primaryKey: const Key('merchant-retry-queue'),
        onSecondary: () => setState(() => _showSaved = true),
        onPrimary: widget.onRetry,
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          const MerchantHero(
            icon: Icons.priority_high,
            iconColor: DealGoColors.danger,
            background: DealGoColors.dangerSurface,
            title: 'Không tải được đơn hàng',
            message: 'Máy chủ chưa phản hồi hoặc kết nối không ổn định. Danh sách đơn hiện tại có thể chưa mới nhất.',
          ),
          const SizedBox(height: DealGoSpacing.s24),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kết nối', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                const MerchantChip(
                  label: 'Tải dữ liệu thất bại',
                  tone: MerchantChipTone.warning,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                MerchantMoneyRow(
                  label: 'Đồng bộ gần nhất',
                  value: formatSyncClock(widget.syncedAt),
                ),
                const MerchantMoneyRow(
                  label: 'Chế độ cửa hàng',
                  value: 'Không tự đổi',
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const MerchantNote(
            message: 'Không coi lỗi mạng là "0 đơn"; không tự chuyển sang chế độ tạm đóng.',
          ),
          if (_showSaved) ...[
            const SizedBox(height: DealGoSpacing.s16),
            if (widget.saved.isEmpty)
              Text('Chưa có đơn đã lưu trên máy.', style: textTheme.bodyMedium)
            else ...[
              Text('Đơn đã lưu', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s8),
              for (final order in widget.saved) ...[
                MerchantPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đơn #${order.id}', style: textTheme.titleMedium),
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(order.status, style: textTheme.bodySmall),
                      Text(order.dropoff.label, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s8),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
