import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/auth_redirect.dart';

enum Gender { male, female, other }

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  DateTime? _selectedDob;
  Gender _selectedGender = Gender.male;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onSkip() {
    if (mounted) {
      context.go(AuthRoutes.permissions);
    }
  }

  Future<void> _onSubmit() async {
    setState(() => _submitting = true);
    // Profile information persistence or update if needed
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      context.go(AuthRoutes.permissions);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: DealGoColors.primary,
              onPrimary: Colors.white,
              onSurface: DealGoColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nameController.text.trim().isNotEmpty && !_submitting;

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        _onSkip();
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: DealGoColors.text,
                    ),
                  ),
                  const Text(
                    'Hoàn thiện hồ sơ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: DealGoColors.text,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoDimensions.pageGutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: DealGoSpacing.s8),

                    // Hero Banner Note
                    Container(
                      padding: const EdgeInsets.all(DealGoSpacing.s12),
                      decoration: BoxDecoration(
                        color: DealGoColors.subtlePurple,
                        borderRadius: BorderRadius.circular(DealGoRadius.card),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: DealGoColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: DealGoSpacing.s8),
                          const Expanded(
                            child: Text(
                              'Chỉ còn một bước nữa thôi! Hoàn thiện thông tin để trải nghiệm trọn vẹn cùng DealGo.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: DealGoColors.primaryPressed,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s20),

                    // Avatar Picker
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: DealGoColors.canvas,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DealGoColors.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: 52,
                              color: DealGoColors.textSecondary,
                            ),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: DealGoColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    const Text(
                      'Ảnh đại diện (tuỳ chọn)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: DealGoColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s20),

                    // Name Field
                    _FormField(
                      label: 'Họ và tên *',
                      child: TextField(
                        key: const Key('name-field'),
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DealGoColors.text,
                        ),
                        decoration: _inputDecoration(hint: 'Nguyễn Văn A'),
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s16),

                    // Email Field
                    _FormField(
                      label: 'Email (tuỳ chọn)',
                      child: TextField(
                        key: const Key('email-field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DealGoColors.text,
                        ),
                        decoration: _inputDecoration(
                          hint: 'example@gmail.com',
                          prefixIcon: Icons.email_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s16),

                    // Date of Birth
                    _FormField(
                      label: 'Ngày sinh (tuỳ chọn)',
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(DealGoRadius.input),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(DealGoRadius.input),
                            border: Border.all(color: DealGoColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDob == null
                                    ? 'Chọn ngày sinh'
                                    : '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: _selectedDob == null
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                  color: _selectedDob == null
                                      ? DealGoColors.textSecondary
                                      : DealGoColors.text,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: DealGoColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s16),

                    // Gender Field
                    _FormField(
                      label: 'Giới tính',
                      child: Row(
                        children: [
                          Expanded(
                            child: _GenderPill(
                              label: 'Nam',
                              selected: _selectedGender == Gender.male,
                              onTap: () => setState(() => _selectedGender = Gender.male),
                            ),
                          ),
                          const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            child: _GenderPill(
                              label: 'Nữ',
                              selected: _selectedGender == Gender.female,
                              onTap: () => setState(() => _selectedGender = Gender.female),
                            ),
                          ),
                          const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            child: _GenderPill(
                              label: 'Khác',
                              selected: _selectedGender == Gender.other,
                              onTap: () => setState(() => _selectedGender = Gender.other),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s20),

                    // Info Note
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: DealGoColors.canvas,
                        borderRadius: BorderRadius.circular(DealGoRadius.input),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: DealGoColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Thông tin này giúp cá nhân hoá trải nghiệm DealGo của bạn.',
                              style: TextStyle(
                                fontSize: 12,
                                color: DealGoColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: DealGoSpacing.s24),
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
                    label: 'Hoàn tất',
                    trailingIcon: Icons.arrow_forward_rounded,
                    isLoading: _submitting,
                    enabled: canSubmit,
                    onPressed: _onSubmit,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  DealGoSecondaryButton(
                    label: 'Bổ sung sau',
                    onPressed: _onSkip,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: DealGoColors.textSecondary,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: DealGoColors.textSecondary)
          : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        borderSide: const BorderSide(color: DealGoColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        borderSide: const BorderSide(color: DealGoColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        borderSide: const BorderSide(color: DealGoColors.primary, width: 1.6),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: DealGoColors.text,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        child,
      ],
    );
  }
}

class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DealGoRadius.input),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: selected ? DealGoColors.subtlePurple : Colors.white,
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          border: Border.all(
            color: selected ? DealGoColors.primary : DealGoColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? DealGoColors.primary : DealGoColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
