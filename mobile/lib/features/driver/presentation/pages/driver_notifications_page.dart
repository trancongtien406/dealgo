import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../widgets/driver_widgets.dart';

enum _DriverNoticeFilter { all, jobs, earnings, system }

class _DriverNotice {
  const _DriverNotice({
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
  final _DriverNoticeFilter filter;
  final String title;
  final String body;
  final String when;
  final IconData icon;
  final Color background;
  final Color foreground;
}

const _driverNotices = <_DriverNotice>[
  _DriverNotice(
    section: 'Hôm nay',
    filter: _DriverNoticeFilter.jobs,
    title: 'Có yêu cầu chở khách gần bạn',
    body: 'Mẫu tài xế · Chuyến #DG-R26001 · Cách 1,2 km',
    when: 'Vừa xong',
    icon: Icons.two_wheeler,
    background: DealGoColors.subtlePurple,
    foreground: DealGoColors.primary,
  ),
  _DriverNotice(
    section: 'Hôm nay',
    filter: _DriverNoticeFilter.jobs,
    title: 'Đơn giao món sẵn sàng nhận',
    body: 'Mẫu tài xế · Bún Bò Huế O Cô · Phí giao 25.000đ',
    when: '8 phút trước',
    icon: Icons.inventory_2_outlined,
    background: DealGoColors.amberSurface,
    foreground: DealGoColors.amber,
  ),
  _DriverNotice(
    section: 'Hôm nay',
    filter: _DriverNoticeFilter.earnings,
    title: 'Đối soát COD đã cập nhật',
    body: 'Mẫu tài xế · Cần nộp 130.000đ sau ca hôm nay',
    when: '35 phút trước',
    icon: Icons.payments_outlined,
    background: DealGoColors.greenSurface,
    foreground: DealGoColors.brandGreen,
  ),
  _DriverNotice(
    section: 'Hôm qua',
    filter: _DriverNoticeFilter.system,
    title: 'Nhắc lịch bảo hiểm tài xế',
    body: 'Mẫu tài xế · Kiểm tra giấy tờ trước ca sáng mai',
    when: 'Hôm qua',
    icon: Icons.verified_user_outlined,
    background: DealGoColors.canvas,
    foreground: DealGoColors.textSecondary,
  ),
];

class DriverNotificationsPage extends StatefulWidget {
  const DriverNotificationsPage({super.key});

  @override
  State<DriverNotificationsPage> createState() =>
      _DriverNotificationsPageState();
}

class _DriverNotificationsPageState extends State<DriverNotificationsPage> {
  var _filter = _DriverNoticeFilter.all;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final notice in _driverNotices)
        if (_filter == _DriverNoticeFilter.all || notice.filter == _filter)
          notice,
    ];
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thông báo tài xế', style: textTheme.titleLarge),
                        Text(
                          'Tin việc, thu nhập và vận hành — không dùng hộp thư khách',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const DriverChip(label: 'Tài xế', tone: DriverChipTone.green),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                children: [
                  DealGoSegmentedControl(
                    value: _filter.name,
                    onChanged: (id) => setState(
                      () => _filter = _DriverNoticeFilter.values
                          .firstWhere((e) => e.name == id),
                    ),
                    items: const [
                      DealGoSegmentItem(id: 'all', label: 'Tất cả'),
                      DealGoSegmentItem(id: 'jobs', label: 'Việc'),
                      DealGoSegmentItem(id: 'earnings', label: 'Thu nhập'),
                      DealGoSegmentItem(id: 'system', label: 'Hệ thống'),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    'Các mục này là mẫu trên máy cho tài xế, không phải thông báo khách hàng.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  if (visible.isEmpty)
                    const Text('Không có thông báo mẫu trong nhóm này.')
                  else
                    for (final section in const ['Hôm nay', 'Hôm qua'])
                      if (visible.any((n) => n.section == section)) ...[
                        Text(section, style: textTheme.titleMedium),
                        const SizedBox(height: DealGoSpacing.s12),
                        for (final notice in visible)
                          if (notice.section == section) ...[
                            DealGoCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: notice.background,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Icon(
                                        notice.icon,
                                        color: notice.foreground,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: DealGoSpacing.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notice.title,
                                          style: textTheme.titleMedium
                                              ?.copyWith(fontSize: 16),
                                        ),
                                        Text(
                                          notice.body,
                                          style: textTheme.bodySmall,
                                        ),
                                        const SizedBox(
                                          height: DealGoSpacing.s4,
                                        ),
                                        Text(
                                          notice.when,
                                          style: textTheme.labelSmall?.copyWith(
                                            color: DealGoColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
