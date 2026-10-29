import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/post_auth_gate.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/drafts/text_draft.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/permissions/app_permission_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/domain/entities/auth_method_policy.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/domain/repositories/identity_repository.dart';
import '../../../identity/presentation/auth_methods_store.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../identity/presentation/widgets/profile_form.dart';
import '../avatar_image_source.dart';

/// "Hoàn thiện hồ sơ": same [ProfileForm] as "Chỉnh sửa hồ sơ", plus a skip.
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
  late final ProfileFormController _form;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final auth = _maybe<AuthCubit>()?.state;
    _form = ProfileFormController(
      initial: auth is AuthSignedIn ? auth.profile : null,
    );
    // Values typed before an app kill come back on the next launch.
    bindTextDraft('profile.setup', {
      'name': _form.name,
      'email': _form.email,
      'phone': _form.phone,
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  T? _maybe<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _completeProfileAndContinue() async {
    await context.read<PostAuthGate>().setCompletedProfileSetup(true);
    if (!mounted) return;
    final auth = context.read<AuthCubit>().state;
    final roles = auth is AuthSignedIn
        ? auth.profile.activeAppRoles
        : const <AppRole>[];
    context.go(entryPathFor(roles));
  }

  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_form.isComplete || _submitting || !_form.validate(l10n)) return;
    setState(() => _submitting = true);
    try {
      final auth = _maybe<AuthCubit>();
      final repo = _maybe<IdentityRepository>();
      final state = auth?.state;
      if (auth != null && repo != null && state is AuthSignedIn) {
        // Email is a sign-in method: only collected while it is switched on.
        final email =
            authMethodEnabled(context, AuthMethodPolicy.email, listen: false)
            ? _form.email.text.trim()
            : '';
        final updated = await repo.updateMe(
          accessToken: state.tokens.accessToken,
          displayName: _form.name.text.trim(),
          email: email.isEmpty ? null : email,
          dateOfBirth: _form.dateOfBirthApi,
          gender: _form.gender,
          contactPhone: _form.contactPhone,
        );
        await auth.applyUpdatedProfile(updated);
      }
      clearTextDraft();
      if (!mounted) return;
      await _completeProfileAndContinue();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorText(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProfileFormScaffold(
      title: l10n.profileSetupTitle,
      trailing: TextButton(
        key: const Key('profile-skip'),
        onPressed: _submitting
            ? null
            : () => unawaited(_completeProfileAndContinue()),
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
      form: ProfileForm(
        controller: _form,
        permissionService: widget.permissionService,
        avatarImageSource: widget.avatarImageSource,
        onSubmitted: () => unawaited(_onSubmit()),
      ),
      action: ListenableBuilder(
        listenable: _form,
        builder: (context, _) => DealGoPrimaryButton(
          label: l10n.profileDone,
          trailingIcon: DealGoIcons.arrowRight,
          isLoading: _submitting,
          enabled: _form.isComplete && !_submitting,
          onPressed: _onSubmit,
        ),
      ),
    );
  }
}
