import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/auth/post_auth_gate.dart';
import '../../../../core/design_system/components/dealgo_date_time_picker.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/permissions/app_permission_service.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/domain/entities/user_profile.dart';
import '../../../identity/domain/repositories/identity_repository.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../avatar_image_source.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/api_error_text.dart';

enum Gender { male, female, other }

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    this.permissionService,
    this.avatarImageSource,
  });

  final AppPermissionService? permissionService;
  final AvatarImageSource? avatarImageSource;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  DateTime? _selectedDob;
  Gender _selectedGender = Gender.male;
  bool _submitting = false;
  bool _uploadingAvatar = false;
  Uint8List? _avatarPreview;
  String? _avatarUrl;
  late final AvatarImageSource _avatarSource =
      widget.avatarImageSource ?? ImagePickerAvatarSource();

  @override
  void initState() {
    super.initState();
    final auth = _maybeAuth()?.state;
    if (auth is AuthSignedIn) {
      _avatarUrl = auth.profile.avatarUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String get _genderApiValue {
    switch (_selectedGender) {
      case Gender.male:
        return UserGender.male;
      case Gender.female:
        return UserGender.female;
      case Gender.other:
        return UserGender.other;
    }
  }

  Future<void> _completeProfileAndContinue() async {
    final gate = context.read<PostAuthGate>();
    await gate.setCompletedProfileSetup(true);
    if (!mounted) {
      return;
    }
    final auth = context.read<AuthCubit>().state;
    final roles = auth is AuthSignedIn
        ? auth.profile.activeAppRoles
        : const <AppRole>[];
    context.go(entryPathFor(roles));
  }

  void _onSkip() {
    unawaited(_completeProfileAndContinue());
  }

  Future<void> _onSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final auth = _maybeAuth();
      final repo = _maybeRepo();
      if (auth != null && repo != null && auth.state is AuthSignedIn) {
        final token = (auth.state as AuthSignedIn).tokens.accessToken;
        final email = _emailController.text.trim();
        final dob = _selectedDob;
        final updated = await repo.updateMe(
          accessToken: token,
          displayName: name,
          email: email.isEmpty ? null : email,
          dateOfBirth: dob == null
              ? null
              : '${dob.year.toString().padLeft(4, '0')}-'
                    '${dob.month.toString().padLeft(2, '0')}-'
                    '${dob.day.toString().padLeft(2, '0')}',
          gender: _genderApiValue,
        );
        await auth.applyUpdatedProfile(updated);
      }
      if (!mounted) {
        return;
      }
      await _completeProfileAndContinue();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorText(AppLocalizations.of(context), error)),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  AppPermissionService? _resolvePermissions() {
    if (widget.permissionService != null) {
      return widget.permissionService;
    }
    try {
      return context.read<AppPermissionService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  AuthCubit? _maybeAuth() {
    try {
      return context.read<AuthCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  IdentityRepository? _maybeRepo() {
    try {
      return context.read<IdentityRepository>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _onAvatarTap() async {
    final service = _resolvePermissions();
    if (service != null) {
      final photosOk = await service.ensurePhotos();
      if (!photosOk) {
        await service.ensureCamera();
      }
    }
    if (!mounted) {
      return;
    }

    final picked = await _avatarSource.pickFromGallery();
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _avatarPreview = picked.bytes;
      _uploadingAvatar = true;
    });

    try {
      final auth = _maybeAuth();
      final repo = _maybeRepo();
      if (auth != null && repo != null && auth.state is AuthSignedIn) {
        final token = (auth.state as AuthSignedIn).tokens.accessToken;
        final url = await repo.uploadAvatar(
          accessToken: token,
          contentBase64: picked.contentBase64,
          contentType: picked.contentType,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _avatarUrl = url;
          _uploadingAvatar = false;
        });
        final current = auth.state;
        if (current is AuthSignedIn) {
          await auth.applyUpdatedProfile(
            current.profile.copyWith(avatarUrl: url),
          );
        }
      } else if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorText(AppLocalizations.of(context), error)),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nameController.text.trim().isNotEmpty && !_submitting;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
                vertical: DealGoSpacing.s8,
              ),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    AuthBackButton(onPressed: () => Navigator.of(context).pop())
                  else
                    const SizedBox(width: DealGoDimensions.minTapTarget),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).profileSetupTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: DealGoDimensions.minTapTarget),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  0,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
                      decoration: BoxDecoration(
                        color: DealGoColors.subtlePurple,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF6D28D9)
                              .withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                      .profileSetupHeadline,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4338CA),
                                    height: 1.25,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF475569),
                                      height: 1.35,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: AppLocalizations.of(context)
                                            .profileSetupLead,
                                      ),
                                      const TextSpan(
                                        text: 'Deal',
                                        style: TextStyle(
                                          color: Color(0xFF6D28D9),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: 'Go',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: Image.asset(
                              'assets/images/hero_dealgo_danang.png',
                              height: 108,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    DealGoIcons.stars,
                                    size: 48,
                                    color: Color(0xFF6D28D9),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => unawaited(_onAvatarTap()),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 92,
                                      height: 92,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        shape: BoxShape.circle,
                                        image: _avatarPreview != null
                                            ? DecorationImage(
                                                image: MemoryImage(
                                                  _avatarPreview!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : resolveMediaUrl(_avatarUrl) !=
                                                  null
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  resolveMediaUrl(_avatarUrl)!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child:
                                          _avatarPreview == null &&
                                              resolveMediaUrl(_avatarUrl) ==
                                                  null
                                          ? const Center(
                                              child: Icon(
                                                DealGoIcons.user,
                                                size: 52,
                                                color: Color(0xFF8B5CF6),
                                              ),
                                            )
                                          : (_uploadingAvatar
                                                ? Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      ),
                                                    ),
                                                  )
                                                : null),
                                    ),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6D28D9),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          DealGoIcons.camera,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(context)
                                      .profileAvatarOptional,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          DealGoTextField(
                            fieldKey: const Key('name-field'),
                            label: AppLocalizations.of(context).profileFullName,
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            prefixIcon: DealGoIcons.user,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          DealGoTextField(
                            fieldKey: const Key('email-field'),
                            label: 'Email',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: DealGoIcons.mail,
                          ),
                          const SizedBox(height: 16),
                          DealGoDateField(
                            label: AppLocalizations.of(context)
                                .profileBirthdayOptional,
                            value: _selectedDob,
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                            onChanged: (picked) =>
                                setState(() => _selectedDob = picked),
                          ),
                          const SizedBox(height: 16),
                          _FormField(
                            label: AppLocalizations.of(context).profileGender,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _GenderPill(
                                    label: AppLocalizations.of(context)
                                        .profileGenderMale,
                                    icon: DealGoIcons.male,
                                    color: const Color(0xFF6D28D9),
                                    selected: _selectedGender == Gender.male,
                                    onTap: () => setState(
                                      () => _selectedGender = Gender.male,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _GenderPill(
                                    label: AppLocalizations.of(context)
                                        .profileGenderFemale,
                                    icon: DealGoIcons.female,
                                    color: const Color(0xFFEC4899),
                                    selected: _selectedGender == Gender.female,
                                    onTap: () => setState(
                                      () => _selectedGender = Gender.female,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _GenderPill(
                                    label: AppLocalizations.of(context)
                                        .profileGenderOther,
                                    icon: DealGoIcons.genderOther,
                                    color: const Color(0xFF10B981),
                                    selected: _selectedGender == Gender.other,
                                    onTap: () => setState(
                                      () => _selectedGender = Gender.other,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  DealGoIcons.info,
                                  size: 18,
                                  color: Color(0xFF6D28D9),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF475569),
                                        height: 1.35,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: AppLocalizations.of(context)
                                              .profilePersonalizeNote,
                                        ),
                                        const TextSpan(
                                          text: 'Deal',
                                          style: TextStyle(
                                            color: Color(0xFF6D28D9),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: 'Go',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    label: AppLocalizations.of(context).profileDone,
                    trailingIcon: DealGoIcons.arrowRight,
                    isLoading: _submitting,
                    enabled: canSubmit,
                    onPressed: _onSubmit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      AppLocalizations.of(context).profileLater,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
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
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
