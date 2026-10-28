import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/network/request_failure.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/push/new_job_alert.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/app_role.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/account_settings.dart';

class NotificationPrefsPage extends StatefulWidget {
  const NotificationPrefsPage({super.key});

  @override
  State<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends State<NotificationPrefsPage> {
  NotificationPrefs? _prefs;
  var _loading = true;
  var _busy = false;
  String? _error;
  String? _ok;
  Object? _loadFailure;

  String? get _token {
    final s = context.read<AuthCubit>().state;
    return s is AuthSignedIn ? s.tokens.accessToken : null;
  }

  /// "Âm báo có đơn mới" only matters to people who receive jobs / store orders.
  bool get _receivesJobs {
    final s = context.read<AuthCubit>().state;
    if (s is! AuthSignedIn) return false;
    final roles = s.profile.activeAppRoles;
    return roles.contains(AppRole.driver) || roles.contains(AppRole.merchant);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) {
      setState(() {
        _loading = false;
        _loadFailure = sessionExpiredFailure;
      });
      return;
    }
    try {
      final prefs = await context
          .read<AccountSettingsRepository>()
          .notificationPrefs(accessToken: token);
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _loading = false;
          _loadFailure = null;
        });
      }
      unawaited(NewJobAlert.instance.setCustomSound(prefs.newJobSound));
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailure = error;
        });
      }
    }
  }

  Future<void> _save() async {
    final token = _token;
    final prefs = _prefs;
    if (token == null || prefs == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      final saved = await context
          .read<AccountSettingsRepository>()
          .saveNotificationPrefs(accessToken: token, prefs: prefs);
      unawaited(NewJobAlert.instance.setCustomSound(saved.newJobSound));
      if (mounted) {
        setState(() {
          _prefs = saved;
          _ok = AppLocalizations.of(context).notifPrefsSaved;
        });
      }
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
    final prefs = _prefs;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.card,
      appBar: DealGoAppHeader(
        title: l10n.notifPrefsHeader,
        applySafeArea: true,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : prefs == null
            ? DealGoStateView.failure(
                context,
                onRetry: _load,
                cause: _loadFailure,
                compact: true,
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(
                        DealGoDimensions.pageGutter,
                      ),
                      children: [
                        Text(
                          l10n.notifPrefsTitle,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Banner(
                          icon: DealGoIcons.notifications,
                          title: l10n.notifPrefsPushOn,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.notifPrefsImportant,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _PrefCard(
                          children: [
                            _PrefTile(
                              icon: DealGoIcons.phone,
                              title: l10n.notifPrefsRide,
                              body: l10n.notifPrefsRideBody,
                              value: prefs.ride,
                              onChanged: (v) => setState(
                                () => _prefs = prefs.copyWith(ride: v),
                              ),
                            ),
                            _PrefTile(
                              icon: DealGoIcons.food,
                              title: l10n.notifPrefsFood,
                              body: l10n.notifPrefsFoodBody,
                              value: prefs.food,
                              onChanged: (v) => setState(
                                () => _prefs = prefs.copyWith(food: v),
                              ),
                            ),
                            _PrefTile(
                              icon: DealGoIcons.chat,
                              title: l10n.notifPrefsChat,
                              body: l10n.notifPrefsChatBody,
                              value: prefs.chat,
                              onChanged: (v) => setState(
                                () => _prefs = prefs.copyWith(chat: v),
                              ),
                            ),
                            if (_receivesJobs)
                              _PrefTile(
                                key: const ValueKey('notif-pref-new-job-sound'),
                                icon: DealGoIcons.notificationsActive,
                                title: l10n.notifPrefsNewJobSound,
                                body: l10n.notifPrefsNewJobSoundBody,
                                value: prefs.newJobSound,
                                onChanged: (v) => setState(
                                  () => _prefs = prefs.copyWith(newJobSound: v),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.notifPrefsOther,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _PrefCard(
                          children: [
                            _PrefTile(
                              icon: DealGoIcons.gift,
                              title: l10n.notifPrefsPromo,
                              body: l10n.notifPrefsPromoBody,
                              value: prefs.promotion,
                              onChanged: (v) => setState(
                                () => _prefs = prefs.copyWith(promotion: v),
                              ),
                            ),
                            _PrefTile(
                              icon: DealGoIcons.info,
                              title: l10n.notifPrefsNews,
                              body: l10n.notifPrefsNewsBody,
                              value: prefs.news,
                              onChanged: (v) => setState(
                                () => _prefs = prefs.copyWith(news: v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _Banner(
                          icon: DealGoIcons.info,
                          title: l10n.notifPrefsMandatory,
                          body: '',
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: textTheme.bodySmall?.copyWith(
                              color: DealGoColors.danger,
                            ),
                          ),
                        if (_ok != null)
                          Text(
                            _ok!,
                            style: textTheme.bodySmall?.copyWith(
                              color: DealGoColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                    child: DealGoPrimaryButton(
                      label: l10n.notifPrefsSave,
                      isLoading: _busy,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.title, this.body = ''});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: DealGoColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (body.isNotEmpty)
                    Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefCard extends StatelessWidget {
  const _PrefCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: DealGoColors.border),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: DealGoColors.primary),
      title: Text(title),
      subtitle: Text(body),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: DealGoColors.primary,
      ),
    );
  }
}
