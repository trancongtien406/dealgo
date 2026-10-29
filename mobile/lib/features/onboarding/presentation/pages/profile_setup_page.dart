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
import '../../../../core/drafts/text_draft.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/permissions/app_permission_service.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/domain/entities/auth_method_policy.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/domain/entities/user_profile.dart';
import '../../../identity/domain/phone_input.dart';
import '../../../identity/domain/repositories/identity_repository.dart';
import '../../../identity/presentation/auth_methods_store.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../../identity/presentation/widgets/auth_scaffold.dart';
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

class _ProfileSetupPageState extends State<ProfileSetupPage>
    with TextDraftMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _phoneError;

  /// Email/passkey accounts have no login phone: ask for a contact phone
  /// (saved as typed, no OTP). Phone-OTP accounts already have one.
  bool _needsPhone = false;
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
      _needsPhone = !auth.profile.hasAnyPhone;
    }
    // Name/email typed before an app kill come back on the next launch.
    bindTextDraft('profile.setup', {
      'name': _nameController,
      'email': _emailController,
      'phone': _phoneController,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
    String? contactPhone;
    if (_needsPhone) {
      contactPhone = vnMobileFromInput(_phoneController.text);
      if (contactPhone == null) {
        setState(
          () => _phoneError = AppLocalizations.of(context).profilePhoneInvalid,
        );
        return;
      }
    }
    setState(() {
      _phoneError = null;
      _submitting = true;
    });
    try {
      final auth = _maybeAuth();
      final repo = _maybeRepo();
      if (auth != null && repo != null && auth.state is AuthSignedIn) {
        final token = (auth.state as AuthSignedIn).tokens.accessToken;
        // Email is a sign-in method: only collected while it is switched on.
        final email =
            authMethodEnabled(context, AuthMethodPolicy.email, listen: false)
            ? _emailController.text.trim()
            : '';
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
          contactPhone: contactPhone,
        );
        await auth.applyUpdatedProfile(updated);
      }
      clearTextDraft();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorText(AppLocalizations.of(context), error)),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorText(AppLocalizations.of(context), error)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSubmit =
        _nameController.text.trim().isNotEmpty &&
        (!_needsPhone || _phoneController.text.trim().isNotEmpty) &&
        !_submitting;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s8,
                vertical: DealGoSpacing.s4,
              ),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    AuthBackButton(onPressed: () => Navigator.of(context).pop())
                  else
                    const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      l10n.profileSetupTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('profile-skip'),
                    onPressed: _submitting ? null : _onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        DealGoDimensions.minTapTarget,
                        DealGoDimensions.minTapTarget,
                      ),
                    ),
                    child: Text(
                      l10n.profileLater,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _avatarPicker(l10n)),
                    const SizedBox(height: 20),
                    DealGoTextField(
                      fieldKey: const Key('name-field'),
                      label: l10n.profileFullName,
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      prefixIcon: DealGoIcons.user,
                      textCapitalization: TextCapitalization.words,
                    ),
                    if (_needsPhone) ...[
                      const SizedBox(height: 12),
                      _FormField(
                        label: l10n.profilePhone,
                        child: AuthPhoneField(
                          controller: _phoneController,
                          errorText: _phoneError,
                          onChanged: (_) => setState(() => _phoneError = null),
                          onSubmitted: () {
                            if (canSubmit) {
                              unawaited(_onSubmit());
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.profilePhoneHint,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                    if (authMethodEnabled(context, AuthMethodPolicy.email)) ...[
                      const SizedBox(height: 12),
                      DealGoTextField(
                        fieldKey: const Key('email-field'),
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: DealGoIcons.mail,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DealGoDateField(
                      label: l10n.profileBirthdayOptional,
                      value: _selectedDob,
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                      onChanged: (picked) =>
                          setState(() => _selectedDob = picked),
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      label: l10n.profileGender,
                      child: Row(
                        children: [
                          for (final option in Gender.values) ...[
                            if (option != Gender.male) const SizedBox(width: 8),
                            Expanded(
                              child: _GenderPill(
                                label: _genderLabel(l10n, option),
                                icon: _genderIcon(option),
                                color: _genderColor(option),
                                selected: _selectedGender == option,
                                onTap: () =>
                                    setState(() => _selectedGender = option),
                              ),
                            ),
                          ],
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
              child: DealGoPrimaryButton(
                label: l10n.profileDone,
                trailingIcon: DealGoIcons.arrowRight,
                isLoading: _submitting,
                enabled: canSubmit,
                onPressed: _onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPicker(AppLocalizations l10n) {
    final remote = resolveMediaUrl(_avatarUrl);
    final ImageProvider? image = _avatarPreview != null
        ? MemoryImage(_avatarPreview!)
        : remote != null
        ? NetworkImage(remote)
        : null;
    return Semantics(
      button: true,
      label: l10n.profileAvatarOptional,
      child: InkWell(
        key: const Key('avatar-picker'),
        onTap: _uploadingAvatar ? null : () => unawaited(_onAvatarTap()),
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                shape: BoxShape.circle,
                image: image == null
                    ? null
                    : DecorationImage(image: image, fit: BoxFit.cover),
              ),
              child: image == null
                  ? const Icon(
                      DealGoIcons.user,
                      size: 44,
                      color: Color(0xFF8B5CF6),
                    )
                  : _uploadingAvatar
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                DealGoIcons.camera,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _genderLabel(AppLocalizations l10n, Gender gender) => switch (gender) {
  Gender.male => l10n.profileGenderMale,
  Gender.female => l10n.profileGenderFemale,
  Gender.other => l10n.profileGenderOther,
};

IconData _genderIcon(Gender gender) => switch (gender) {
  Gender.male => DealGoIcons.male,
  Gender.female => DealGoIcons.female,
  Gender.other => DealGoIcons.genderOther,
};

Color _genderColor(Gender gender) => switch (gender) {
  Gender.male => const Color(0xFF6D28D9),
  Gender.female => const Color(0xFFEC4899),
  Gender.other => const Color(0xFF10B981),
};

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
