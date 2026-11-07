import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_date_time_picker.dart';
import '../../../../core/design_system/components/dealgo_image_cache.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/permissions/app_permission_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/presentation/avatar_image_source.dart';
import '../../domain/entities/auth_method_policy.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/phone_input.dart';
import '../../domain/repositories/identity_repository.dart';
import '../auth_methods_store.dart';
import '../cubit/auth_cubit.dart';
import 'auth_scaffold.dart';
import 'auth_widgets.dart';

/// Values shared by "Hoàn thiện hồ sơ" and "Chỉnh sửa hồ sơ": both screens
/// render [ProfileForm] so the field set and layout never drift apart.
class ProfileFormController extends ChangeNotifier {
  ProfileFormController({UserProfile? initial}) {
    // Without a signed-in profile (previews/tests) the phone is optional.
    phoneRequired = initial != null;
    if (initial != null) {
      final name = initial.displayName.trim();
      // The server placeholder name is not something the user typed.
      if (name.isNotEmpty && name != 'DealGo user') _name.text = name;
      email.text = initial.email ?? '';
      lockedPhone = (initial.phone?.isNotEmpty ?? false) ? initial.phone : null;
      phone.text = displayVnPhone(initial.contactPhone);
      gender = initial.gender ?? UserGender.male;
      final dob = initial.dateOfBirth;
      dateOfBirth = dob == null ? null : DateTime.tryParse(dob);
      avatarUrl = initial.avatarUrl;
    }
  }

  final TextEditingController _name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();

  /// Verified login phone: shown read-only. Null → editable contact phone.
  String? lockedPhone;
  String gender = UserGender.male;
  DateTime? dateOfBirth;
  String? avatarUrl;
  String? phoneError;
  bool phoneRequired = true;

  TextEditingController get name => _name;
  bool get phoneEditable => lockedPhone == null;

  bool get isComplete =>
      _name.text.trim().isNotEmpty &&
      (!phoneEditable || !phoneRequired || phone.text.trim().isNotEmpty);

  /// Validates the contact phone. Returns false (and sets [phoneError]) when
  /// it is invalid; [contactPhone] then holds the normalized value.
  String? contactPhone;
  bool validate(AppLocalizations l10n) {
    contactPhone = null;
    if (phoneEditable && (phoneRequired || phone.text.trim().isNotEmpty)) {
      contactPhone = vnMobileFromInput(phone.text);
      if (contactPhone == null) {
        phoneError = l10n.profilePhoneInvalid;
        notifyListeners();
        return false;
      }
    }
    phoneError = null;
    notifyListeners();
    return true;
  }

  String? get dateOfBirthApi {
    final d = dateOfBirth;
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  void touch() => notifyListeners();

  @override
  void dispose() {
    _name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    required this.controller,
    required this.onSubmitted,
    this.permissionService,
    this.avatarImageSource,
    this.unverifiedEmail,
    this.onVerifyEmail,
    super.key,
  });

  final ProfileFormController controller;
  final VoidCallback onSubmitted;

  /// The account email while it is still unverified; the field then offers
  /// [onVerifyEmail] as long as it still shows that address.
  final String? unverifiedEmail;
  final VoidCallback? onVerifyEmail;
  final AppPermissionService? permissionService;
  final AvatarImageSource? avatarImageSource;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  bool _uploadingAvatar = false;
  Uint8List? _avatarPreview;
  late final AvatarImageSource _avatarSource =
      widget.avatarImageSource ?? ImagePickerAvatarSource();

  ProfileFormController get _c => widget.controller;

  T? _maybe<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  bool _pickingAvatar = false;

  Future<void> _onAvatarTap() async {
    // Double tap while the permission prompt / picker is up: ignore.
    if (_pickingAvatar) return;
    _pickingAvatar = true;
    try {
      await _pickAvatar();
    } finally {
      _pickingAvatar = false;
    }
  }

  Future<void> _pickAvatar() async {
    // No media permission: image_picker opens the system picker (Android SAF /
    // iOS PHPicker), which grants access to just the chosen file. Asking for
    // READ_MEDIA_IMAGES would be an over-broad Play declaration (B2).
    if (!mounted) return;
    final picked = await _avatarSource.pickFromGallery();
    if (picked == null || !mounted) return;
    setState(() {
      _avatarPreview = picked.bytes;
      _uploadingAvatar = true;
    });
    try {
      final auth = _maybe<AuthCubit>();
      final repo = _maybe<IdentityRepository>();
      final state = auth?.state;
      if (auth != null && repo != null && state is AuthSignedIn) {
        final url = await repo.uploadAvatar(
          accessToken: state.tokens.accessToken,
          contentBase64: picked.contentBase64,
          contentType: picked.contentType,
        );
        _c.avatarUrl = url;
        final current = auth.state;
        if (current is AuthSignedIn) {
          await auth.applyUpdatedProfile(
            current.profile.copyWith(avatarUrl: url),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorText(AppLocalizations.of(context), error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _avatarPicker(l10n)),
          const SizedBox(height: 20),
          DealGoTextField(
            fieldKey: const Key('name-field'),
            label: l10n.profileFullName,
            hint: 'Nhập họ và tên của bạn',
            controller: _c.name,
            onChanged: (_) => _c.touch(),
            prefixIcon: DealGoIcons.user,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _FormField(
            label: l10n.profilePhone,
            child: _c.phoneEditable
                ? AuthPhoneField(
                    controller: _c.phone,
                    errorText: _c.phoneError,
                    onChanged: (_) {
                      _c.phoneError = null;
                      _c.touch();
                    },
                    onSubmitted: widget.onSubmitted,
                  )
                : DealGoTextField(
                    fieldKey: const Key('locked-phone-field'),
                    label: l10n.profilePhone,
                    controller: TextEditingController(
                      text: displayVnPhone(_c.lockedPhone),
                    ),
                    enabled: false,
                    prefixIcon: DealGoIcons.phone,
                    suffix: const Icon(DealGoIcons.lock, size: 18),
                  ),
          ),
          if (authMethodEnabled(context, AuthMethodPolicy.email)) ...[
            const SizedBox(height: 12),
            DealGoTextField(
              fieldKey: const Key('email-field'),
              label: 'Email',
              hint: 'Nhập địa chỉ email của bạn',
              controller: _c.email,
              onChanged: (_) => _c.touch(),
              keyboardType: TextInputType.emailAddress,
              prefixIcon: DealGoIcons.mail,
            ),
            if (_showVerifyEmail) _unverifiedEmailRow(l10n),
          ],
          const SizedBox(height: 12),
          DealGoDateField(
            label: l10n.profileBirthdayOptional,
            hint: 'Chọn ngày sinh của bạn',
            value: _c.dateOfBirth,
            firstDate: DateTime(1920),
            lastDate: DateTime.now(),
            onChanged: (picked) {
              _c.dateOfBirth = picked;
              _c.touch();
            },
          ),
          const SizedBox(height: 12),
          _FormField(
            label: l10n.profileGender,
            child: Row(
              children: [
                for (final (i, option) in const [
                  UserGender.male,
                  UserGender.female,
                  UserGender.other,
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _GenderPill(
                      label: _genderLabel(l10n, option),
                      icon: _genderIcon(option),
                      color: _genderColor(option),
                      selected: _c.gender == option,
                      onTap: () {
                        _c.gender = option;
                        _c.touch();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s16,
              vertical: DealGoSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(DealGoRadius.input),
              border: Border.all(
                color: DealGoColors.border.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  DealGoIcons.info,
                  size: 20,
                  color: DealGoColors.primary,
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: DealGoColors.textSecondary,
                        height: 1.4,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Thông tin này giúp cá nhân hoá trải nghiệm ',
                        ),
                        TextSpan(
                          text: 'Deal',
                          style: TextStyle(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Go',
                          style: TextStyle(
                            color: DealGoColors.brandGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _showVerifyEmail {
    final unverified = widget.unverifiedEmail?.toLowerCase();
    return widget.onVerifyEmail != null &&
        unverified != null &&
        unverified.isNotEmpty &&
        _c.email.text.trim().toLowerCase() == unverified;
  }

  Widget _unverifiedEmailRow(AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(DealGoIcons.info, size: 16, color: DealGoColors.textSecondary),
        const SizedBox(width: DealGoSpacing.s6),
        Expanded(
          child: Text(
            l10n.profileEmailUnverified,
            style: textTheme.labelMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          key: const Key('email-verify-action'),
          onPressed: widget.onVerifyEmail,
          child: Text(l10n.profileEmailVerifyAction),
        ),
      ],
    );
  }

  Widget _avatarPicker(AppLocalizations l10n) {
    final remote = resolveMediaUrl(_c.avatarUrl);
    final ImageProvider? image = _avatarPreview != null
        ? MemoryImage(_avatarPreview!)
        : remote != null
        ? DealGoImageCache.provider(remote, decodeWidth: 260)
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

String _genderLabel(AppLocalizations l10n, String gender) => switch (gender) {
  UserGender.female => l10n.profileGenderFemale,
  UserGender.other => l10n.profileGenderOther,
  _ => l10n.profileGenderMale,
};

IconData _genderIcon(String gender) => switch (gender) {
  UserGender.female => DealGoIcons.female,
  UserGender.other => DealGoIcons.genderOther,
  _ => DealGoIcons.male,
};

Color _genderColor(String gender) => switch (gender) {
  UserGender.female => const Color(0xFFEC4899),
  UserGender.other => const Color(0xFF10B981),
  _ => const Color(0xFF6D28D9),
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
          style: TextStyle(
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
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
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

/// Page chrome shared by both profile screens: title row, scrolling form,
/// primary action pinned at the bottom.
class ProfileFormScaffold extends StatelessWidget {
  const ProfileFormScaffold({
    required this.title,
    required this.form,
    required this.action,
    this.trailing,
    this.canLeave = true,
    super.key,
  });

  final String title;
  final Widget form;
  final Widget action;
  final Widget? trailing;

  /// False on the post-signup screen: back would leave the profile unfinished.
  final bool canLeave;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    Widget headerRow = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DealGoSpacing.s8,
        vertical: DealGoSpacing.s4,
      ),
      child: SizedBox(
        height: DealGoDimensions.minTapTarget,
        child: Row(
          children: [
            if (canLeave && Navigator.of(context).canPop())
              AuthBackButton(onPressed: () => Navigator.of(context).maybePop())
            else
              const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DealGoColors.text,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: DealGoColors.card,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackdrop()),
          SafeArea(
            child: isTablet
                ? Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        vertical: DealGoSpacing.s24,
                        horizontal: DealGoSpacing.s16,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          decoration: BoxDecoration(
                            color: DealGoColors.card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: DealGoColors.border.withValues(alpha: 0.8),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x140F172A),
                                blurRadius: 28,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              headerRow,
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  DealGoSpacing.s24,
                                  DealGoSpacing.s8,
                                  DealGoSpacing.s24,
                                  DealGoSpacing.s16,
                                ),
                                child: form,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  DealGoSpacing.s24,
                                  DealGoSpacing.s8,
                                  DealGoSpacing.s24,
                                  DealGoSpacing.s24,
                                ),
                                child: action,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      headerRow,
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            DealGoDimensions.pageGutter,
                            DealGoSpacing.s8,
                            DealGoDimensions.pageGutter,
                            DealGoSpacing.s16,
                          ),
                          child: form,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s8,
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s16,
                        ),
                        child: action,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
