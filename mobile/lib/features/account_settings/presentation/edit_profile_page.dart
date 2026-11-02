import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/drafts/text_draft.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_method_policy.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/repositories/identity_repository.dart';
import '../../identity/presentation/auth_methods_store.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../identity/presentation/widgets/email_verification_sheet.dart';
import '../../identity/presentation/widgets/profile_form.dart';

/// "Chỉnh sửa hồ sơ": same [ProfileForm] and layout as "Hoàn thiện hồ sơ".
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with TextDraftMixin {
  late final ProfileFormController _form;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    _form = ProfileFormController(
      initial: auth is AuthSignedIn ? auth.profile : null,
    );
    // Unsaved edits survive an app kill; cleared after a successful save.
    bindTextDraft('profile.edit', {
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn || _busy || !_form.isComplete) return;
    if (!_form.validate(l10n)) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = context.read<IdentityRepository>();
      final cubit = context.read<AuthCubit>();
      // Email is a sign-in method: only sent while it is switched on.
      final email =
          authMethodEnabled(context, AuthMethodPolicy.email, listen: false)
          ? _form.email.text.trim()
          : '';
      final updated = await repo.updateMe(
        accessToken: auth.tokens.accessToken,
        displayName: _form.name.text.trim(),
        email: email.isEmpty ? null : email,
        dateOfBirth: _form.dateOfBirthApi,
        gender: _form.gender,
        contactPhone: _form.contactPhone,
      );
      await cubit.applyUpdatedProfile(updated);
      clearTextDraft();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('profile-saved-snack'),
          content: Text(l10n.editProfileSaved),
        ),
      );
      if (!mounted) return;
      final verified = await verifySubmittedProfileEmail(
        context: context,
        submittedEmail: email,
        accountEmail: updated.email,
        repository: repo,
        auth: cubit,
        accessToken: auth.tokens.accessToken,
      );
      _showEmailOutcome(messenger, l10n, verified);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCurrentEmail(String email) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthCubit>();
    final state = auth.state;
    if (state is! AuthSignedIn || _busy) return;
    final repo = context.read<IdentityRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final verification = await repo.requestEmailVerification(
        accessToken: state.tokens.accessToken,
        email: email,
      );
      if (!mounted) return;
      final verified = await showEmailVerificationSheet(
        context: context,
        verification: verification,
        repository: repo,
        auth: auth,
        accessToken: state.tokens.accessToken,
      );
      _showEmailOutcome(messenger, l10n, verified ? true : null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showEmailOutcome(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    bool? verified,
  ) {
    if (verified == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: Key(verified ? 'email-verified-snack' : 'email-pending-snack'),
        content: Text(
          verified ? l10n.emailVerifySuccess : l10n.emailVerifyPendingNotice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthCubit>().state;
    final profile = auth is AuthSignedIn ? auth.profile : null;
    final unverifiedEmail = profile != null && profile.emailVerifiedAt == null
        ? profile.email
        : null;
    return ProfileFormScaffold(
      title: l10n.editProfileHeader,
      form: ProfileForm(
        controller: _form,
        onSubmitted: () => unawaited(_save()),
        unverifiedEmail: unverifiedEmail,
        onVerifyEmail: unverifiedEmail == null
            ? null
            : () => unawaited(_verifyCurrentEmail(unverifiedEmail)),
      ),
      action: ListenableBuilder(
        listenable: _form,
        builder: (context, _) => DealGoPrimaryButton(
          label: l10n.editProfileSave,
          isLoading: _busy,
          enabled: _form.isComplete && !_busy,
          onPressed: _save,
        ),
      ),
    );
  }
}
