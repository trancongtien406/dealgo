import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../cubit/merchant_kyb_cubit.dart';
import '../utils/merchant_kyb_routes.dart';
import '../widgets/onboarding_widgets.dart';

void _seedMerchantKyb(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  if (auth is AuthSignedIn) {
    context.read<MerchantKybCubit>().seedFromProfile(auth.profile);
  }
}

class MerchantKybGatePage extends StatefulWidget {
  const MerchantKybGatePage({super.key});

  @override
  State<MerchantKybGatePage> createState() => _MerchantKybGatePageState();
}

class _MerchantKybGatePageState extends State<MerchantKybGatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _seedMerchantKyb(context);
      final target = MerchantKybRoutes.entryFromCubit(
        context.read<MerchantKybCubit>(),
      );
      context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MerchantKybIntroPage extends StatefulWidget {
  const MerchantKybIntroPage({super.key});

  @override
  State<MerchantKybIntroPage> createState() => _MerchantKybIntroPageState();
}

class _MerchantKybIntroPageState extends State<MerchantKybIntroPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _seedMerchantKyb(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: MerchantKybCopy.introTitle,
      roleBadge: MerchantKybCopy.roleBadge,
      onBack: () => context.canPop() ? context.pop() : context.go('/merchant'),
      footer: OnboardingContinueBar(
        label: MerchantKybCopy.startCta,
        onPressed: () {
          context.read<MerchantKybCubit>().startDraft();
          context.go(MerchantKybRoutes.steps);
        },
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
            'Đối tác cửa hàng',
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          OnboardingStatusChip(
            label: MerchantKybCopy.flowLabel,
            tone: OnboardingBannerTone.neutral,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(MerchantKybCopy.introHeadline, style: textTheme.titleLarge),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            MerchantKybCopy.introBody,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          DealGoCard(
            child: Column(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 48,
                  color: DealGoColors.primary,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  'Từ gian hàng nhỏ đến cửa hàng phát triển',
                  style: textTheme.titleMedium?.copyWith(
                    color: DealGoColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          Text('DealGo đồng hành cùng bạn', style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          const _BenefitGrid(),
          const SizedBox(height: DealGoSpacing.s16),
          const OnboardingInfoBanner(
            message: 'Bạn cần cung cấp thông tin về cửa hàng, người đại diện và giấy tờ phù hợp để được xét duyệt.',
          ),
        ],
      ),
    );
  }
}

class MerchantKybStepsPage extends StatelessWidget {
  const MerchantKybStepsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantKybCubit, MerchantKybState>(
      builder: (context, state) {
        final cubit = context.read<MerchantKybCubit>();
        final title = switch (state.step) {
          MerchantKybStep.businessType => 'Loại hình kinh doanh',
          MerchantKybStep.shopInfo => 'Thông tin cửa hàng',
          MerchantKybStep.representative => 'Người đại diện',
          MerchantKybStep.documents => 'Tài liệu kinh doanh',
          MerchantKybStep.review => 'Rà soát hồ sơ Shop',
        };
        return OnboardingScaffold(
          title: title,
          roleBadge: MerchantKybCopy.roleBadge,
          onBack: () {
            if (state.step == MerchantKybStep.businessType) {
              context.go(MerchantKybRoutes.intro);
              return;
            }
            cubit.previousStep();
          },
          footer: OnboardingContinueBar(
            label: state.step == MerchantKybStep.review
                ? MerchantKybCopy.submitCta
                : 'Tiếp tục',
            enabled:
                state.step != MerchantKybStep.documents || state.docsAttached,
            onPressed: () async {
              if (state.step == MerchantKybStep.review) {
                await cubit.submit();
                if (!context.mounted) {
                  return;
                }
                if (cubit.state.submitError == null &&
                    cubit.state.status == PartnerApplicationStatus.pending) {
                  context.go(MerchantKybRoutes.status);
                }
                return;
              }
              if (state.step == MerchantKybStep.documents &&
                  !state.docsAttached) {
                return;
              }
              cubit.nextStep();
            },
          ),
          body: ListView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              OnboardingStepHeader(
                flowLabel: 'THÔNG TIN CỬA HÀNG',
                stepLabel: 'Bước ${state.stepNumber} / ${state.totalSteps}',
                currentStep: state.stepNumber,
                totalSteps: state.totalSteps,
                headline: switch (state.step) {
                  MerchantKybStep.businessType => 'Bạn kinh doanh gì?',
                  MerchantKybStep.shopInfo => 'Thông tin cửa hàng',
                  MerchantKybStep.representative => 'Người đại diện',
                  MerchantKybStep.documents => 'Tài liệu kinh doanh',
                  MerchantKybStep.review => 'Rà soát hồ sơ Shop',
                },
                subtitle: switch (state.step) {
                  MerchantKybStep.businessType => 'Chọn loại hình phù hợp để DealGo gợi ý danh mục sản phẩm và quy trình xác minh.',
                  MerchantKybStep.shopInfo =>
                    'Tên và địa chỉ dùng khi xét duyệt và hiển thị cho khách.',
                  MerchantKybStep.representative =>
                    'Thông tin người đại diện pháp lý của cửa hàng.',
                  MerchantKybStep.documents => 'Mock UI — không tải ảnh lên Nest. Chỉ đánh dấu đã đính kèm.',
                  MerchantKybStep.review => 'Kiểm tra trước khi gửi',
                },
              ),
              const SizedBox(height: DealGoSpacing.s20),
              switch (state.step) {
                MerchantKybStep.businessType => _BusinessTypeStep(state: state),
                MerchantKybStep.shopInfo => _ShopInfoStep(state: state),
                MerchantKybStep.representative => _RepStep(state: state),
                MerchantKybStep.documents => OnboardingMockDocSlot(
                  title: 'Giấy tờ kinh doanh',
                  hint: 'Đính kèm mock — không upload thật',
                  attached: state.docsAttached,
                  onToggle: cubit.toggleDocsAttached,
                ),
                MerchantKybStep.review => _MerchantReviewStep(state: state),
              },
            ],
          ),
        );
      },
    );
  }
}

class MerchantKybStatusPage extends StatefulWidget {
  const MerchantKybStatusPage({super.key});

  @override
  State<MerchantKybStatusPage> createState() => _MerchantKybStatusPageState();
}

class _MerchantKybStatusPageState extends State<MerchantKybStatusPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _seedMerchantKyb(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantKybCubit, MerchantKybState>(
      builder: (context, state) {
        final isActive = state.status == PartnerApplicationStatus.active;
        final textTheme = Theme.of(context).textTheme;
        return OnboardingScaffold(
          title: 'Trạng thái xét duyệt Shop',
          roleBadge: MerchantKybCopy.roleBadge,
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/merchant'),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingContinueBar(
                label: isActive ? 'Về trang Shop' : MerchantKybCopy.trackCta,
                onPressed: () => context.go('/merchant'),
              ),
              if (!isActive) ...[
                const SizedBox(height: DealGoSpacing.s8),
                DealGoSecondaryButton(
                  label: 'Demo: từ chối hồ sơ',
                  onPressed: () {
                    context.read<MerchantKybCubit>().simulateReject();
                    context.go(MerchantKybRoutes.rejected);
                  },
                ),
              ],
              if (isActive) ...[
                const SizedBox(height: DealGoSpacing.s8),
                DealGoSecondaryButton(
                  label: 'Xem lại đăng ký (mock)',
                  onPressed: () {
                    context.read<MerchantKybCubit>().startDraft();
                    context.go(MerchantKybRoutes.intro);
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
                      isActive ? Icons.verified : Icons.description_outlined,
                      size: 40,
                      color: DealGoColors.primary,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Text(
                      isActive
                          ? MerchantKybCopy.activeTitle
                          : MerchantKybCopy.pendingTitle,
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      isActive ? MerchantKybCopy.activeBody : state.shopName,
                      style: textTheme.bodyMedium?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    OnboardingStatusChip(
                      label: isActive ? 'ACTIVE' : MerchantKybCopy.pendingBadge,
                      tone: isActive
                          ? OnboardingBannerTone.success
                          : OnboardingBannerTone.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Text('Tiến trình kiểm tra', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              const _MerchantTimeline(
                title: 'Đã tiếp nhận hồ sơ',
                subtitle: '12/10/2026 · Mã DEMO-SHOP-001',
                done: true,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              _MerchantTimeline(
                title: 'Đối chiếu giấy tờ',
                subtitle: isActive
                    ? 'Đã xác minh hợp lệ'
                    : 'Đang chờ xác minh hợp lệ',
                done: isActive,
                current: !isActive,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              _MerchantTimeline(
                title: 'Kích hoạt bán hàng',
                subtitle: 'Chỉ sau khi được phê duyệt',
                done: isActive,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              OnboardingInfoBanner(
                message: isActive
                    ? 'Seed mock đã ACTIVE — nhận đơn không bị khóa bởi màn này.'
                    : 'Chưa có thời hạn duyệt được bảo đảm. Ứng dụng sẽ cập nhật khi backend thay đổi trạng thái.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class MerchantKybRejectedPage extends StatelessWidget {
  const MerchantKybRejectedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantKybCubit, MerchantKybState>(
      builder: (context, state) {
        final cubit = context.read<MerchantKybCubit>();
        return OnboardingScaffold(
          title: 'Bổ sung hồ sơ Shop',
          roleBadge: MerchantKybCopy.roleBadge,
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/merchant'),
          footer: OnboardingContinueBar(
            label: MerchantKybCopy.resubmitCta,
            onPressed: () async {
              await cubit.resubmit();
              if (!context.mounted) {
                return;
              }
              if (cubit.state.submitError == null &&
                  cubit.state.status == PartnerApplicationStatus.pending) {
                context.go(MerchantKybRoutes.status);
              }
            },
          ),
          body: ListView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              const OnboardingInfoBanner(
                message: MerchantKybCopy.rejectedBanner,
                tone: OnboardingBannerTone.warning,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(height: DealGoSpacing.s20),
              Text(
                'Lý do cần chỉnh sửa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              OnboardingRejectionList(items: state.rejections),
              Row(
                children: [
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: 'Tải ảnh lại',
                      onPressed: () {
                        cubit.beginResubmit();
                        context.go(MerchantKybRoutes.steps);
                      },
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: 'Sửa địa chỉ',
                      onPressed: () {
                        cubit.beginResubmit();
                        cubit.goToStep(MerchantKybStep.shopInfo);
                        context.go(MerchantKybRoutes.steps);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s20),
              const OnboardingInfoBanner(
                message: 'Sau khi gửi lại, trạng thái chuyển sang RE_SUBMITTED. Không tự hiển thị “Đã duyệt” chỉ vì upload thành công.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid();

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String, String)>[
      (
        Icons.restaurant,
        'Tiếp cận khách hàng',
        'Hiển thị cửa hàng và món ăn theo khu vực',
      ),
      (
        Icons.notifications_none,
        'Nhận và xử lý đơn',
        'Theo dõi đơn mới và đơn đang chuẩn bị',
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Quản lý doanh thu',
        'Thống kê bán hàng và đối soát',
      ),
      (
        Icons.verified_user_outlined,
        'Đăng ký minh bạch',
        'Hồ sơ được xét duyệt trước khi bán',
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          Row(
            children: [
              Expanded(child: _BenefitCard(item: items[i])),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: i + 1 < items.length
                    ? _BenefitCard(item: items[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (i + 2 < items.length) const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.item});

  final (IconData, String, String) item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.$1, color: DealGoColors.primary),
          const SizedBox(height: DealGoSpacing.s8),
          Text(item.$2, style: textTheme.titleMedium?.copyWith(fontSize: 14)),
          const SizedBox(height: DealGoSpacing.s4),
          Text(item.$3, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BusinessTypeStep extends StatelessWidget {
  const _BusinessTypeStep({required this.state});

  final MerchantKybState state;

  static const types = <(String, String, IconData, Color, Color)>[
    (
      'Quán ăn / Nhà hàng',
      'Món ăn chế biến và giao tận nơi.',
      Icons.restaurant,
      DealGoColors.subtlePurple,
      DealGoColors.primary,
    ),
    (
      'Quán cà phê / Trà sữa',
      'Đồ uống, bánh ngọt và đồ ăn nhẹ.',
      Icons.local_cafe_outlined,
      DealGoColors.greenSurface,
      DealGoColors.brandGreen,
    ),
    (
      'Siêu thị / Cửa hàng thực phẩm',
      'Rau củ, thịt cá và đồ gia dụng.',
      Icons.shopping_bag_outlined,
      DealGoColors.subtlePurple,
      DealGoColors.primary,
    ),
    (
      'Cửa hàng tiện lợi',
      'Hàng tiêu dùng và nhu yếu phẩm.',
      Icons.store_mall_directory_outlined,
      DealGoColors.subtlePurple,
      DealGoColors.primary,
    ),
    (
      'Loại hình khác',
      'Chọn danh mục khi khai báo sản phẩm.',
      Icons.add,
      DealGoColors.greenSurface,
      DealGoColors.brandGreen,
    ),
  ];

  static const subjects = ['Hộ kinh doanh', 'Doanh nghiệp', 'Khác'];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MerchantKybCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in types) ...[
          OnboardingSelectCard(
            title: type.$1,
            subtitle: type.$2,
            selected: state.businessType == type.$1,
            icon: type.$3,
            tint: type.$4,
            iconColor: type.$5,
            onTap: () => cubit.selectBusinessType(type.$1),
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        Text('Chủ thể đăng ký', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s12),
        DealGoSegmentedControl(
          value: state.registrationSubject,
          onChanged: cubit.selectRegistrationSubject,
          items: [
            for (final subject in subjects)
              DealGoSegmentItem(id: subject, label: subject),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s16),
        const OnboardingInfoBanner(
          message: 'Danh mục và điều kiện tham gia có thể thay đổi tùy loại hình và vùng cung cấp dịch vụ.',
        ),
      ],
    );
  }
}

class _ShopInfoStep extends StatelessWidget {
  const _ShopInfoStep({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingMockField(
          label: 'Tên cửa hàng',
          value: state.shopName,
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: 'Địa chỉ',
          value: state.shopAddress,
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: 'Loại hình',
          value: state.businessType,
          required: true,
        ),
      ],
    );
  }
}

class _RepStep extends StatelessWidget {
  const _RepStep({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingMockField(
          label: 'Họ và tên',
          value: state.representativeName,
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        const OnboardingMockField(
          label: 'Vai trò',
          value: 'Chủ hộ kinh doanh',
          required: true,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        const OnboardingInfoBanner(
          message: 'Người đại diện chịu trách nhiệm về thông tin khai báo với DealGo.',
          tone: OnboardingBannerTone.neutral,
        ),
      ],
    );
  }
}

class _MerchantReviewStep extends StatelessWidget {
  const _MerchantReviewStep({required this.state});

  final MerchantKybState state;

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
              Text('Tình trạng hồ sơ', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              _MerchantReviewRow(
                title: 'Thông tin cửa hàng',
                subtitle: state.shopName,
              ),
              const _MerchantReviewRow(
                title: 'Người đại diện',
                subtitle: 'Đã cung cấp giấy tờ',
              ),
              _MerchantReviewRow(
                title: 'Tài liệu kinh doanh',
                subtitle: state.docsAttached
                    ? 'Tải đủ theo danh sách yêu cầu'
                    : 'Chưa đính kèm',
              ),
              const _MerchantReviewRow(
                title: 'Ngân hàng nhận tiền',
                subtitle: 'Xác nhận thông tin chủ tài khoản',
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        const OnboardingInfoBanner(
          message: 'Gửi hồ sơ tạo một phiên xét duyệt. Mọi thay đổi về giấy tờ sau khi gửi phải tạo lần bổ sung mới.',
        ),
      ],
    );
  }
}

class _MerchantReviewRow extends StatelessWidget {
  const _MerchantReviewRow({required this.title, required this.subtitle});

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
            label: 'Đủ dữ liệu',
            tone: OnboardingBannerTone.success,
          ),
        ],
      ),
    );
  }
}

class _MerchantTimeline extends StatelessWidget {
  const _MerchantTimeline({
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
                ? 'Đang kiểm tra'
                : 'Chưa kích hoạt',
            tone: done
                ? OnboardingBannerTone.success
                : OnboardingBannerTone.warning,
          ),
        ],
      ),
    );
  }
}
