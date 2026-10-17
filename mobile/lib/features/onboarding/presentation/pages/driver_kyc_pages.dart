import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../cubit/driver_kyc_cubit.dart';
import '../utils/driver_kyc_routes.dart';
import '../widgets/onboarding_widgets.dart';

void _seedDriverKyc(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  if (auth is AuthSignedIn) {
    context.read<DriverKycCubit>().seedFromProfile(auth.profile);
  }
}

class DriverKycGatePage extends StatefulWidget {
  const DriverKycGatePage({super.key});

  @override
  State<DriverKycGatePage> createState() => _DriverKycGatePageState();
}

class _DriverKycGatePageState extends State<DriverKycGatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _seedDriverKyc(context);
      final target = DriverKycRoutes.entryFromCubit(
        context.read<DriverKycCubit>(),
      );
      context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class DriverKycIntroPage extends StatefulWidget {
  const DriverKycIntroPage({super.key});

  @override
  State<DriverKycIntroPage> createState() => _DriverKycIntroPageState();
}

class _DriverKycIntroPageState extends State<DriverKycIntroPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _seedDriverKyc(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: DriverKycCopy.introTitle,
      roleBadge: DriverKycCopy.roleBadge,
      onBack: () => context.canPop() ? context.pop() : context.go('/driver'),
      footer: Row(
        children: [
          Expanded(
            child: DealGoSecondaryButton(
              label: DriverKycCopy.existingCta,
              onPressed: () {
                context.read<DriverKycCubit>().simulateReject();
                context.go(DriverKycRoutes.rejected);
              },
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: OnboardingContinueBar(
              label: DriverKycCopy.startCta,
              onPressed: () {
                context.read<DriverKycCubit>().startDraft();
                context.go(DriverKycRoutes.steps);
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
        children: [
          Row(
            children: [
              Text(
                'DealGo',
                style: textTheme.headlineSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              OnboardingStatusChip(
                label: 'Chế độ đối tác',
                tone: OnboardingBannerTone.neutral,
              ),
            ],
          ),
          Text(
            'Đối tác tài xế',
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoCard(
            child: Column(
              children: [
                const Icon(
                  Icons.two_wheeler,
                  size: 48,
                  color: DealGoColors.primary,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  'Đi muôn nơi\nKiếm thêm thu nhập',
                  style: textTheme.titleMedium?.copyWith(
                    color: DealGoColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          Text(DriverKycCopy.introHeadline, style: textTheme.titleLarge),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            DriverKycCopy.introBody,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          const _IntroFeature(
            icon: Icons.directions_car_outlined,
            title: 'Chở khách',
            subtitle: 'Nhận chuyến và chào giá theo nhu cầu',
            badge: 'Ride',
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const _IntroFeature(
            icon: Icons.delivery_dining_outlined,
            title: 'Giao đồ ăn',
            subtitle: 'Lấy món tại Shop và giao đến khách',
            badge: 'Food',
            green: true,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const _IntroFeature(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Theo dõi thu nhập',
            subtitle: 'Minh bạch mỗi chuyến và khoản đối soát',
          ),
          const SizedBox(height: DealGoSpacing.s16),
          const OnboardingInfoBanner(
            message: 'Cần xác minh trước khi hoạt động: CCCD, nhận diện khuôn mặt, giấy phép lái xe và thông tin phương tiện theo loại dịch vụ đăng ký.',
            icon: Icons.verified_user_outlined,
          ),
        ],
      ),
    );
  }
}

class DriverKycStepsPage extends StatelessWidget {
  const DriverKycStepsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverKycCubit, DriverKycState>(
      builder: (context, state) {
        final cubit = context.read<DriverKycCubit>();
        final textTheme = Theme.of(context).textTheme;
        final title = switch (state.step) {
          DriverKycStep.services => 'Chọn dịch vụ',
          DriverKycStep.personal => 'Thông tin cá nhân',
          DriverKycStep.identity => 'Chụp CCCD',
          DriverKycStep.ocrConfirm => 'Xác nhận OCR',
          DriverKycStep.selfie => 'Selfie / liveness',
          DriverKycStep.license => 'Giấy phép lái xe',
          DriverKycStep.vehicle => 'Phương tiện',
          DriverKycStep.bank => 'Liên kết ngân hàng',
          DriverKycStep.review => 'Rà soát hồ sơ tài xế',
        };
        return OnboardingScaffold(
          title: title,
          roleBadge: DriverKycCopy.roleBadge,
          onBack: () {
            if (state.step == DriverKycStep.services) {
              context.go(DriverKycRoutes.intro);
              return;
            }
            cubit.previousStep();
          },
          footer: OnboardingContinueBar(
            label: state.step == DriverKycStep.review
                ? DriverKycCopy.submitCta
                : 'Tiếp tục',
            enabled: switch (state.step) {
              DriverKycStep.services => state.canContinueServices,
              DriverKycStep.identity => state.idAttached,
              DriverKycStep.selfie => state.selfieAttached,
              DriverKycStep.license => state.licenseAttached,
              DriverKycStep.bank => state.bankAttached,
              _ => true,
            },
            onPressed: () async {
              if (state.step == DriverKycStep.review) {
                await cubit.submit();
                if (!context.mounted) {
                  return;
                }
                if (cubit.state.submitError == null &&
                    cubit.state.status == PartnerApplicationStatus.pending) {
                  context.go(DriverKycRoutes.status);
                }
                return;
              }
              cubit.nextStep();
            },
          ),
          body: ListView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              OnboardingStepHeader(
                flowLabel: DriverKycCopy.flowLabel,
                stepLabel: 'Bước ${state.stepNumber}/${state.totalSteps}',
                currentStep: state.stepNumber,
                totalSteps: state.totalSteps,
                headline: title,
                subtitle: switch (state.step) {
                  DriverKycStep.services =>
                    'Bạn có thể đăng ký nhiều dịch vụ, tùy theo hồ sơ và phương tiện được xét duyệt.',
                  DriverKycStep.personal =>
                    'Vui lòng nhập đúng như trên giấy tờ định danh để tránh sai lệch trong xác minh.',
                  DriverKycStep.identity =>
                    'Mock UI — không tải ảnh lên Nest. Chỉ đánh dấu đã đính kèm để đi tiếp.',
                  DriverKycStep.ocrConfirm =>
                    'Đối chiếu dữ liệu OCR mock với thông tin bạn đã nhập.',
                  DriverKycStep.selfie =>
                    'Selfie / liveness mock — không gọi camera production.',
                  DriverKycStep.license =>
                    'Khai báo GPLX hợp lệ theo dịch vụ đã chọn.',
                  DriverKycStep.vehicle =>
                    'Thông tin phương tiện dùng khi xét duyệt điều kiện nhận việc.',
                  DriverKycStep.bank =>
                    'Liên kết tài khoản nhận đối soát (mock — không gọi ngân hàng).',
                  DriverKycStep.review => 'Kiểm tra trước khi gửi xét duyệt',
                },
              ),
              const SizedBox(height: DealGoSpacing.s20),
              switch (state.step) {
                DriverKycStep.services => _ServicesStep(state: state),
                DriverKycStep.personal => _PersonalStep(state: state),
                DriverKycStep.identity => OnboardingMockDocSlot(
                  title: 'CCCD mặt trước / mặt sau',
                  hint: 'Đính kèm mock — không upload thật',
                  attached: state.idAttached,
                  onToggle: cubit.toggleIdAttached,
                ),
                DriverKycStep.ocrConfirm => DealGoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Họ tên OCR', style: textTheme.titleMedium),
                      Text(state.fullName),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text('Ngày sinh', style: textTheme.titleMedium),
                      Text(state.birthDate),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text('Địa chỉ', style: textTheme.titleMedium),
                      Text(state.address),
                      const SizedBox(height: DealGoSpacing.s12),
                      const OnboardingInfoBanner(
                        message:
                            'OCR là stub UI. Không coi đây là xác minh pháp lý.',
                      ),
                    ],
                  ),
                ),
                DriverKycStep.selfie => OnboardingMockDocSlot(
                  title: 'Ảnh selfie / liveness',
                  hint: 'Đính kèm mock — không capture thật',
                  attached: state.selfieAttached,
                  onToggle: cubit.toggleSelfieAttached,
                ),
                DriverKycStep.license => OnboardingMockDocSlot(
                  title: 'Giấy phép lái xe',
                  hint: 'Đính kèm mock — không upload thật',
                  attached: state.licenseAttached,
                  onToggle: cubit.toggleLicenseAttached,
                ),
                DriverKycStep.vehicle => _VehicleStep(state: state),
                DriverKycStep.bank => OnboardingMockDocSlot(
                  title: 'Tài khoản ngân hàng nhận tiền',
                  hint: 'Đính kèm mock — không liên kết PSP',
                  attached: state.bankAttached,
                  onToggle: cubit.toggleBankAttached,
                ),
                DriverKycStep.review => _ReviewStep(state: state),
              },
            ],
          ),
        );
      },
    );
  }
}

class DriverKycStatusPage extends StatefulWidget {
  const DriverKycStatusPage({super.key});

  @override
  State<DriverKycStatusPage> createState() => _DriverKycStatusPageState();
}

class _DriverKycStatusPageState extends State<DriverKycStatusPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _seedDriverKyc(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverKycCubit, DriverKycState>(
      builder: (context, state) {
        final isActive = state.status == PartnerApplicationStatus.active;
        final textTheme = Theme.of(context).textTheme;
        return OnboardingScaffold(
          title: 'Kết quả xét duyệt KYC',
          roleBadge: DriverKycCopy.roleBadge,
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/driver'),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingContinueBar(
                label: isActive ? 'Về trang Tài xế' : DriverKycCopy.trackCta,
                onPressed: () => context.go('/driver'),
              ),
              if (!isActive) ...[
                const SizedBox(height: DealGoSpacing.s8),
                DealGoSecondaryButton(
                  label: 'Demo: từ chối hồ sơ',
                  onPressed: () {
                    context.read<DriverKycCubit>().simulateReject();
                    context.go(DriverKycRoutes.rejected);
                  },
                ),
              ],
              if (isActive) ...[
                const SizedBox(height: DealGoSpacing.s8),
                DealGoSecondaryButton(
                  label: 'Xem lại đăng ký (mock)',
                  onPressed: () {
                    context.read<DriverKycCubit>().startDraft();
                    context.go(DriverKycRoutes.intro);
                  },
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              DealGoCard(
                child: Column(
                  children: [
                    Icon(
                      isActive ? Icons.verified : Icons.schedule,
                      size: 40,
                      color: DealGoColors.primary,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Text(
                      isActive
                          ? DriverKycCopy.activeTitle
                          : DriverKycCopy.pendingTitle,
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      isActive
                          ? DriverKycCopy.activeBody
                          : 'Hồ sơ tài xế ${state.fullName}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    OnboardingStatusChip(
                      label: isActive ? 'ACTIVE' : DriverKycCopy.pendingBadge,
                      tone: isActive
                          ? OnboardingBannerTone.success
                          : OnboardingBannerTone.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Text('Tiến trình hồ sơ', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              const _TimelineRow(
                title: 'Đã gửi hồ sơ',
                subtitle: '12/10/2026 · KYC-DRV-DEMO-01',
                done: true,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              _TimelineRow(
                title: 'Xác minh giấy tờ',
                subtitle: isActive ? 'Đã đối chiếu' : 'Đang đối chiếu',
                done: isActive,
                current: !isActive,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              _TimelineRow(
                title: 'Kích hoạt nhận việc',
                subtitle: 'Chỉ khi từng quyền dịch vụ được chấp thuận',
                done: isActive,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              OnboardingInfoBanner(
                message: isActive
                    ? 'Seed mock đã ACTIVE — Online/Nhận chuyến không bị khóa bởi màn này.'
                    : 'Ứng dụng cập nhật kết quả khi backend thay đổi quyền. Không cho phép bật Online nếu chưa đủ điều kiện.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class DriverKycRejectedPage extends StatelessWidget {
  const DriverKycRejectedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverKycCubit, DriverKycState>(
      builder: (context, state) {
        final cubit = context.read<DriverKycCubit>();
        return OnboardingScaffold(
          title: 'Bổ sung hồ sơ tài xế',
          roleBadge: DriverKycCopy.roleBadge,
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/driver'),
          footer: OnboardingContinueBar(
            label: DriverKycCopy.resubmitCta,
            onPressed: () async {
              await cubit.resubmit();
              if (!context.mounted) {
                return;
              }
              if (cubit.state.submitError == null &&
                  cubit.state.status == PartnerApplicationStatus.pending) {
                context.go(DriverKycRoutes.status);
              }
            },
          ),
          body: ListView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              const OnboardingInfoBanner(
                message: DriverKycCopy.rejectedBanner,
                tone: OnboardingBannerTone.warning,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(height: DealGoSpacing.s20),
              Text(
                'Giấy tờ cần sửa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              OnboardingRejectionList(items: state.rejections),
              Row(
                children: [
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: 'Chụp lại CCCD',
                      onPressed: () {
                        cubit.beginResubmit();
                        context.go(DriverKycRoutes.steps);
                      },
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: 'Cập nhật GPLX',
                      onPressed: () {
                        cubit.beginResubmit();
                        cubit.goToStep(DriverKycStep.license);
                        context.go(DriverKycRoutes.steps);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s20),
              const OnboardingInfoBanner(
                message: 'Gửi lại chuyển hồ sơ sang RE_SUBMITTED. Quyền nhận việc chỉ mở khi việc xác minh mới đã hoàn tất.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IntroFeature extends StatelessWidget {
  const _IntroFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.green = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Row(
        children: [
          Icon(
            icon,
            color: green ? DealGoColors.brandGreen : DealGoColors.primary,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (badge != null)
            OnboardingStatusChip(
              label: badge!,
              tone: green
                  ? OnboardingBannerTone.success
                  : OnboardingBannerTone.neutral,
            ),
        ],
      ),
    );
  }
}

class _ServicesStep extends StatelessWidget {
  const _ServicesStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DriverKycCubit>();
    return Column(
      children: [
        OnboardingSelectCard(
          title: 'Chở khách',
          subtitle: 'Nhận chuyến, thỏa thuận giá và đón hành khách',
          selected: state.rideService,
          multiSelect: true,
          icon: Icons.directions_car_outlined,
          tint: DealGoColors.subtlePurple,
          iconColor: DealGoColors.primary,
          onTap: cubit.toggleRide,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingSelectCard(
          title: 'Giao đồ ăn',
          subtitle: 'Lấy món tại cửa hàng, giao đến khách hàng',
          selected: state.foodService,
          multiSelect: true,
          icon: Icons.shopping_bag_outlined,
          tint: DealGoColors.greenSurface,
          iconColor: DealGoColors.brandGreen,
          onTap: cubit.toggleFood,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        const OnboardingInfoBanner(
          message: 'Có thể bật/tắt từng dịch vụ sau khi được phê duyệt.',
        ),
      ],
    );
  }
}

class _PersonalStep extends StatelessWidget {
  const _PersonalStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingMockField(
          label: 'Họ và tên',
          value: state.fullName,
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: 'Ngày sinh',
          value: state.birthDate,
          required: true,
          trailing: const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: DealGoColors.textSecondary,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        const OnboardingMockField(
          label: 'Quốc tịch',
          value: 'Việt Nam',
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: 'Địa chỉ liên hệ',
          value: state.address,
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        const OnboardingInfoBanner(
          message: 'Thông tin pháp lý chỉ sử dụng để xét duyệt đối tác, được bảo vệ theo chính sách dữ liệu của DealGo.',
          tone: OnboardingBannerTone.neutral,
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }
}

class _VehicleStep extends StatelessWidget {
  const _VehicleStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingMockField(
          label: 'Loại phương tiện',
          value: state.vehicleType,
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: 'Biển số',
          value: state.vehiclePlate,
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        const OnboardingInfoBanner(
          message: 'Mock — không gọi API đăng kiểm. Dữ liệu chỉ lưu trên thiết bị trong phiên demo.',
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hồ sơ cá nhân', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              _ReviewRow(title: 'Thông tin tài xế', subtitle: state.fullName),
              _ReviewRow(
                title: 'CCCD',
                subtitle: state.idAttached
                    ? 'Đã tải dữ liệu, chờ xác minh'
                    : 'Chưa đính kèm',
              ),
              _ReviewRow(
                title: 'Selfie / liveness',
                subtitle: state.selfieAttached
                    ? 'Đã đính kèm mock'
                    : 'Chưa đính kèm',
              ),
              _ReviewRow(
                title: 'Giấy phép lái xe',
                subtitle: state.licenseAttached
                    ? 'Đã khai báo, chưa có kết luận'
                    : 'Chưa đính kèm',
              ),
              _ReviewRow(
                title: 'Ngân hàng nhận tiền',
                subtitle: state.bankAttached
                    ? 'Đã khai báo mock'
                    : 'Chưa đính kèm',
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        const OnboardingInfoBanner(
          message: 'Gửi hồ sơ sẽ tạo một bản ghi xét duyệt; các nút Online/Nhận chuyến vẫn bị khóa cho đến khi backend phê duyệt.',
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DealGoSpacing.s12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: DealGoColors.brandGreen),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          const OnboardingStatusChip(
            label: 'Đã nhập',
            tone: OnboardingBannerTone.success,
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.subtitle,
    this.done = false,
    this.current = false,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle
                : current
                ? Icons.schedule
                : Icons.circle_outlined,
            color: done ? DealGoColors.brandGreen : DealGoColors.amber,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          OnboardingStatusChip(
            label: done
                ? 'Hoàn thành'
                : current
                ? 'Đang xử lý'
                : 'Chờ',
            tone: done
                ? OnboardingBannerTone.success
                : OnboardingBannerTone.warning,
          ),
        ],
      ),
    );
  }
}
