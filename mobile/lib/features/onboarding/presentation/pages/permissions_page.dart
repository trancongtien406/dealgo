import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _locationGranted = false;
  bool _notificationsGranted = false;
  bool _microphoneGranted = false;
  bool _submitting = false;

  void _finish() {
    if (mounted) {
      // User decision: After onboarding / permissions, go straight to Customer Home (/customer)
      context.go('/customer');
    }
  }

  Future<void> _allowAll() async {
    setState(() {
      _submitting = true;
      _locationGranted = true;
      _notificationsGranted = true;
      _microphoneGranted = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
                vertical: DealGoSpacing.s8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Deal',
                          style: TextStyle(color: DealGoColors.primary),
                        ),
                        TextSpan(
                          text: 'Go',
                          style: TextStyle(color: DealGoColors.brandGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoDimensions.pageGutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: DealGoSpacing.s12),

                    // Shield Icon Badge
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: DealGoColors.subtlePurple,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DealGoColors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.verified_user_rounded,
                          size: 36,
                          color: DealGoColors.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s16),

                    // Headline
                    const Text(
                      'Cho phép truy cập',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: DealGoColors.text,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: DealGoSpacing.s8),

                    const Text(
                      'Bật các quyền cần thiết để trải nghiệm DealGo đầy đủ và thuận tiện nhất.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: DealGoColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: DealGoSpacing.s24),

                    // Permission Cards
                    _PermissionCard(
                      icon: Icons.location_on_rounded,
                      iconColor: DealGoColors.primary,
                      iconBackground: DealGoColors.subtlePurple,
                      title: 'Vị trí',
                      description: 'Tìm tài xế, quán ăn và cửa hàng gần bạn nhất với lộ trình chính xác.',
                      granted: _locationGranted,
                      onToggle: () => setState(() => _locationGranted = !_locationGranted),
                    ),

                    const SizedBox(height: DealGoSpacing.s12),

                    _PermissionCard(
                      icon: Icons.notifications_active_rounded,
                      iconColor: DealGoColors.brandGreen,
                      iconBackground: const Color(0xFFE8F5E9),
                      title: 'Thông báo',
                      description: 'Nhận cập nhật theo thời gian thực về chuyến đi, đồ ăn và ưu đãi hot.',
                      granted: _notificationsGranted,
                      onToggle: () => setState(() => _notificationsGranted = !_notificationsGranted),
                    ),

                    const SizedBox(height: DealGoSpacing.s12),

                    _PermissionCard(
                      icon: Icons.phone_in_talk_rounded,
                      iconColor: DealGoColors.amber,
                      iconBackground: const Color(0xFFFFF3E0),
                      title: 'Micro & Cuộc gọi',
                      description: 'Liên lạc nhanh với tài xế hoặc nhà hàng khi cần trao đổi về đơn.',
                      granted: _microphoneGranted,
                      onToggle: () => setState(() => _microphoneGranted = !_microphoneGranted),
                    ),

                    const SizedBox(height: DealGoSpacing.s20),

                    // Footer notice
                    const Text(
                      'Bạn có thể thay đổi các quyền này bất cứ lúc nào trong phần Cài đặt thiết bị.',
                      style: TextStyle(
                        fontSize: 12,
                        color: DealGoColors.textSecondary,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: DealGoSpacing.s16),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
              ),
              child: Column(
                children: [
                  DealGoPrimaryButton(
                    label: 'Cho phép tất cả',
                    trailingIcon: Icons.arrow_forward_rounded,
                    isLoading: _submitting,
                    onPressed: _allowAll,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  DealGoSecondaryButton(
                    label: 'Thiết lập sau',
                    onPressed: _finish,
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

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.granted,
    required this.onToggle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DealGoSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(
          color: granted ? iconColor : DealGoColors.border,
          width: granted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: DealGoColors.text,
                      ),
                    ),
                    InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: granted ? DealGoColors.brandGreen : DealGoColors.canvas,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (granted)
                              const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            else
                              const Text(
                                'Cho phép',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: DealGoColors.primary,
                                ),
                              ),
                            if (granted) ...[
                              const SizedBox(width: 4),
                              const Text(
                                'Đã bật',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: DealGoColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
