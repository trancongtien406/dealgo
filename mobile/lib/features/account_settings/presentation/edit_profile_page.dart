import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_date_time_picker.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/drafts/text_draft.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_method_policy.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/entities/user_profile.dart';
import '../../identity/domain/repositories/identity_repository.dart';
import '../../identity/presentation/auth_methods_store.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with TextDraftMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  DateTime? _dob;
  String? _gender;
  var _busy = false;
  String? _error;
  String? _ok;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    if (auth is AuthSignedIn) {
      final p = auth.profile;
      _name.text = p.displayName;
      _email.text = p.email ?? '';
      _gender = p.gender;
      if (p.dateOfBirth != null) {
        _dob = DateTime.tryParse(p.dateOfBirth!);
      }
    }
    // Unsaved edits survive an app kill; cleared after a successful save.
    bindTextDraft('profile.edit', {'name': _name, 'email': _email});
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      final repo = context.read<IdentityRepository>();
      final cubit = context.read<AuthCubit>();
      final updated = await repo.updateMe(
        accessToken: auth.tokens.accessToken,
        displayName: _name.text.trim(),
        // Email is a sign-in method: only sent while it is switched on.
        email:
            !authMethodEnabled(
                  context,
                  AuthMethodPolicy.email,
                  listen: false,
                ) ||
                _email.text.trim().isEmpty
            ? null
            : _email.text.trim(),
        dateOfBirth: _dob?.toIso8601String().split('T').first,
        gender: _gender,
      );
      await cubit.applyUpdatedProfile(updated);
      clearTextDraft();
      if (!mounted) return;
      setState(() => _ok = AppLocalizations.of(context).editProfileSaved);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorText(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthCubit>().state;
    final phone = auth is AuthSignedIn ? (auth.profile.phone ?? '') : '';
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.card,
      appBar: DealGoAppHeader(
        title: l10n.editProfileHeader,
        applySafeArea: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: DealGoColors.primary.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      _initials(_name.text),
                      style: textTheme.headlineSmall?.copyWith(
                        color: DealGoColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    l10n.editProfileChangePhoto,
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s20),
            DealGoTextField(
              label: l10n.editProfileName,
              controller: _name,
              onChanged: (_) => setState(() {}),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DealGoTextField(
                label: l10n.editProfilePhone,
                controller: TextEditingController(text: phone),
                enabled: false,
                suffix: const Icon(DealGoIcons.lock, size: 18),
                helper: l10n.editProfilePhoneLocked,
              ),
            ],
            if (authMethodEnabled(context, AuthMethodPolicy.email)) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DealGoTextField(label: l10n.editProfileEmail, controller: _email),
            ],
            const SizedBox(height: DealGoSpacing.s12),
            DealGoDateField(
              label: l10n.editProfileDob,
              value: _dob,
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
              onChanged: (picked) => setState(() => _dob = picked),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Text(l10n.editProfileGender, style: textTheme.titleSmall),
            const SizedBox(height: DealGoSpacing.s8),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in [
                  (UserGender.male, l10n.editProfileGenderMale),
                  (UserGender.female, l10n.editProfileGenderFemale),
                  (UserGender.other, l10n.editProfileGenderOther),
                ])
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: _gender == entry.$1,
                    onSelected: (_) => setState(() => _gender = entry.$1),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(
                  color: DealGoColors.danger,
                ),
              ),
            ],
            if (_ok != null) ...[
              const SizedBox(height: 12),
              Text(
                _ok!,
                style: textTheme.bodySmall?.copyWith(
                  color: DealGoColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 20),
            DealGoPrimaryButton(
              label: l10n.editProfileSave,
              isLoading: _busy,
              enabled: _name.text.trim().isNotEmpty,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
