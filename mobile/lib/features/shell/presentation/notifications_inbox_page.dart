import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'account_widgets.dart';

enum _InboxFilter { all, orders, rides, system }

class _NoticeDraft {
  const _NoticeDraft({
    required this.section,
    required this.filter,
    required this.title,
    required this.body,
    required this.when,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String section;
  final _InboxFilter filter;
  final String title;
  final String body;
  final String when;
  final IconData icon;
  final Color background;
  final Color foreground;
}

const _notices = <_NoticeDraft>[
  _NoticeDraft(
    section: 'Hôm nay',
    filter: _InboxFilter.rides,
    title: 'Tài xế đã đến gần bạn',
    body: 'Mẫu · Chuyến xe DG-R2301 · Còn khoảng 3 phút',
    when: 'Vừa xong',
    icon: Icons.directions_car_outlined,
    background: DealGoColors.greenSurface,
    foreground: DealGoColors.brandGreen,
  ),
  _NoticeDraft(
    section: 'Hôm nay',
    filter: _InboxFilter.orders,
    title: 'Đơn hàng đang được chuẩn bị',
    body: 'Mẫu · Bún Bò Huế Ô Cồ đã xác nhận đơn #DG123456',
    when: '12 phút trước',
    icon: Icons.inventory_2_outlined,
    background: DealGoColors.amberSurface,
    foreground: DealGoColors.amber,
  ),
  _NoticeDraft(
    section: 'Hôm nay',
    filter: _InboxFilter.system,
    title: 'Bạn có tin nhắn mới',
    body: 'Mẫu · Tài xế: “Mình đang tới điểm đón nhé.”',
    when: '25 phút trước',
    icon: Icons.chat_bubble_outline,
    background: DealGoColors.subtlePurple,
    foreground: DealGoColors.primary,
  ),
  _NoticeDraft(
    section: 'Hôm qua',
    filter: _InboxFilter.system,
    title: 'Ưu đãi mới dành cho bạn',
    body: 'Mẫu · Giảm 20.000đ cho đơn hàng từ 99.000đ',
    when: 'Hôm qua',
    icon: Icons.card_giftcard_outlined,
    background: DealGoColors.dangerSurface,
    foreground: DealGoColors.danger,
  ),
  _NoticeDraft(
    section: 'Hôm qua',
    filter: _InboxFilter.rides,
    title: 'Chuyến đi đã hoàn tất',
    body: 'Mẫu · Biên nhận chuyến DG-R2290 đã sẵn sàng',
    when: 'Hôm qua',
    icon: Icons.check_circle_outline,
    background: DealGoColors.greenSurface,
    foreground: DealGoColors.brandGreen,
  ),
];

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  var _filter = _InboxFilter.all;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final notice in _notices)
        if (_filter == _InboxFilter.all || notice.filter == _filter) notice,
    ];
    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountScreenHeader(
              title: 'Thông báo',
              trailing: IconButton(
                tooltip: 'Cài đặt thông báo',
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
                color: DealGoColors.text,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                children: [
                  _FilterRow(
                    selected: _filter,
                    onSelected: (filter) => setState(() => _filter = filter),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    'Các mục này là mẫu trên máy, không phải thông báo từ máy chủ.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  if (visible.isEmpty)
                    const Text('Không có mẫu trên máy trong nhóm này.')
                  else
                    for (final section in _sectionOrder)
                      if (visible.any(
                        (notice) => notice.section == section,
                      )) ...[
                        AccountSectionHeader(
                          title: section,
                          action: section == 'Hôm nay'
                              ? const AccountLinkText('Đánh dấu đã đọc')
                              : null,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        for (final notice in visible)
                          if (notice.section == section) ...[
                            _NoticeCard(notice: notice),
                            const SizedBox(height: DealGoSpacing.s12),
                          ],
                      ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _sectionOrder = ['Hôm nay', 'Hôm qua'];

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final _InboxFilter selected;
  final ValueChanged<_InboxFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoSegmentedControl(
      value: selected.name,
      onChanged: (id) => onSelected(
        _InboxFilter.values.firstWhere((e) => e.name == id),
      ),
      items: [
        DealGoSegmentItem(id: 'all', label: l10n.filterAll),
        DealGoSegmentItem(id: 'orders', label: l10n.filterOrders),
        DealGoSegmentItem(id: 'rides', label: l10n.filterRides),
        DealGoSegmentItem(id: 'system', label: l10n.filterSystem),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final _NoticeDraft notice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountToneIcon(
            icon: notice.icon,
            background: notice.background,
            foreground: notice.foreground,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(notice.body, style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(notice.when, style: textTheme.bodySmall),
              const SizedBox(height: DealGoSpacing.s8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: DealGoColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
