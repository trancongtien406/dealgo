import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import 'account_widgets.dart';

enum _HelpTopic { ride, food, payment, account }

class _Faq {
  const _Faq({
    required this.question,
    required this.answer,
    required this.topic,
  });

  final String question;
  final String answer;
  final _HelpTopic topic;
}

const _faqs = <_Faq>[
  _Faq(
    question: 'Làm thế nào để hủy chuyến?',
    answer: 'Mẫu trên máy: ứng dụng chưa gửi yêu cầu hủy.',
    topic: _HelpTopic.ride,
  ),
  _Faq(
    question: 'Tôi chưa nhận được đơn hàng',
    answer: 'Mẫu trên máy: chưa có trạng thái đơn từ máy chủ.',
    topic: _HelpTopic.food,
  ),
  _Faq(
    question: 'Khi nào nhận được tiền hoàn?',
    answer: 'Mẫu trên máy: thời điểm hoàn tiền do máy chủ quyết định.',
    topic: _HelpTopic.payment,
  ),
];

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _open = <String>{};
  _HelpTopic? _topic;
  var _keptLocal = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _visible(_Faq faq) {
    final topic = _topic;
    if (topic != null && faq.topic != topic) {
      return false;
    }
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return faq.question.toLowerCase().contains(query) ||
        faq.answer.toLowerCase().contains(query);
  }

  void _toggle(String question) {
    setState(() {
      if (!_open.add(question)) {
        _open.remove(question);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final faq in _faqs)
        if (_visible(faq)) faq,
    ];
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccountScreenHeader(title: 'Trung tâm hỗ trợ'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  const _SupportBanner(),
                  const SizedBox(height: DealGoSpacing.s16),
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: accountFieldDecoration(
                      context,
                      hint: 'Tìm câu trả lời hoặc hướng dẫn...',
                      prefix: const Icon(
                        Icons.search,
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  Text('Bạn cần hỗ trợ về?', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  _TopicGrid(
                    selected: _topic,
                    onSelected: (topic) => setState(() {
                      _topic = _topic == topic ? null : topic;
                    }),
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  AccountSectionHeader(
                    title: 'Câu hỏi thường gặp',
                    action: TextButton(
                      onPressed: () => setState(() => _topic = null),
                      child: const AccountLinkText('Xem tất cả'),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    'Câu trả lời là mẫu trên máy, chưa được gửi tới bộ phận hỗ trợ.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  if (visible.isEmpty)
                    Text(
                      'Không có hướng dẫn mẫu cho từ khóa này.',
                      style: textTheme.bodyMedium,
                    )
                  else
                    for (final faq in visible) ...[
                      _FaqCard(
                        faq: faq,
                        open: _open.contains(faq.question),
                        onTap: () => _toggle(faq.question),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_keptLocal) ...[
                    Text(
                      'Bản nháp này chưa được gửi.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  DealGoPrimaryButton(
                    label: 'Tạo yêu cầu hỗ trợ mới',
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () => setState(() => _keptLocal = true),
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

class _SupportBanner extends StatelessWidget {
  const _SupportBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoSpacing.s12,
                        vertical: DealGoSpacing.s4,
                      ),
                      child: Text(
                        'DealGo Support',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    'Chúng mình có thể giúp gì cho bạn?',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    'Hỗ trợ bạn trên mọi hành trình và đơn hàng.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(DealGoRadius.input),
              ),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.headset_mic_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({required this.selected, required this.onSelected});

  final _HelpTopic? selected;
  final ValueChanged<_HelpTopic> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.ride,
                selected: selected == _HelpTopic.ride,
                icon: Icons.directions_car_outlined,
                title: 'Đặt xe',
                subtitle: 'Chuyến đi và tài xế',
                onSelected: onSelected,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.food,
                selected: selected == _HelpTopic.food,
                icon: Icons.restaurant_outlined,
                title: 'Đồ ăn',
                subtitle: 'Đơn hàng và quán',
                onSelected: onSelected,
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.payment,
                selected: selected == _HelpTopic.payment,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Thanh toán',
                subtitle: 'Giao dịch & hoàn tiền',
                onSelected: onSelected,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.account,
                selected: selected == _HelpTopic.account,
                icon: Icons.shield_outlined,
                title: 'Tài khoản',
                subtitle: 'Đăng nhập và bảo mật',
                onSelected: onSelected,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelected,
  });

  final _HelpTopic topic;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<_HelpTopic> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      onTap: () => onSelected(topic),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountToneIcon(
            icon: icon,
            background: DealGoColors.subtlePurple,
            foreground: DealGoColors.primary,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(title, style: textTheme.titleMedium?.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle, style: textTheme.bodySmall),
          if (selected) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              'Đang xem',
              style: textTheme.labelSmall?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.faq, required this.open, required this.onTap});

  final _Faq faq;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccountToneIcon(
                icon: Icons.help_outline,
                background: DealGoColors.subtlePurple,
                foreground: DealGoColors.primary,
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Text(
                  faq.question,
                  style: textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
              ),
              Icon(
                open ? Icons.expand_less : Icons.chevron_right,
                color: DealGoColors.textSecondary,
              ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: DealGoSpacing.s12),
            Text(faq.answer, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
