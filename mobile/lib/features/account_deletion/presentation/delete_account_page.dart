import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_icon_badge.dart';
import '../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../food/domain/entities/food_money.dart';
import '../../identity/domain/auth_redirect.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/passkey_platform.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/account_deletion.dart';

/// Typed confirmation; the mockup asks for "XÓA" (both Vietnamese spellings accepted).
bool isDeleteConfirmationWord(String raw) {
  final word = raw.trim().toUpperCase();
  return word == 'XÓA' || word == 'XOÁ' || word == 'XOA';
}

String deletionBlockerText(
  AppLocalizations l10n,
  AccountDeletionBlocker blocker,
) {
  final count = blocker.count ?? 1;
  return switch (blocker.code) {
    'ACTIVE_RIDE' => l10n.deleteBlockerRide(count),
    'ACTIVE_FOOD_ORDER' => l10n.deleteBlockerFood(count),
    'ACTIVE_DRIVER_JOB' => l10n.deleteBlockerDriver(count),
    'STORE_OPEN_ORDERS' => l10n.deleteBlockerStore(count),
    'UNSETTLED_COD' => l10n.deleteBlockerCod(formatVnd(blocker.amountVnd ?? 0)),
    'OPS_ACCOUNT' => l10n.deleteBlockerOps,
    _ => l10n.apiErrConflict,
  };
}

enum _Phase { loading, loadError, form, verify, done }

/// S027 — request → re-auth (native passkey prompt, SMS OTP or password) → soft-delete;
/// purge after the grace period.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _word = TextEditingController();
  final _secret = TextEditingController();
  var _phase = _Phase.loading;
  AccountDeletionOverview? _overview;
  AccountDeletionChallenge? _challenge;
  AccountDeletionScheduled? _scheduled;
  List<AccountDeletionBlocker> _blockers = const [];
  var _backedUp = false;
  var _busy = false;
  String? _error;
  var _mustRestart = false;

  AccountDeletionRepository get _repo =>
      context.read<AccountDeletionRepository>();

  String? get _token {
    final state = context.read<AuthCubit>().state;
    return state is AuthSignedIn ? state.tokens.accessToken : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _word.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) {
      setState(() => _phase = _Phase.loadError);
      return;
    }
    setState(() => _phase = _Phase.loading);
    try {
      final overview = await _repo.overview(accessToken: token);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _blockers = overview.blockers;
        _phase = _Phase.form;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.loadError);
    }
  }

  bool get _canContinue =>
      !_busy &&
      _blockers.isEmpty &&
      _overview?.method != null &&
      _backedUp &&
      isDeleteConfirmationWord(_word.text);

  Future<void> _start() async {
    final token = _token;
    if (token == null || !_canContinue) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    AccountDeletionChallenge? started;
    try {
      started = await _repo.start(accessToken: token);
      if (!mounted) return;
      setState(() {
        _challenge = started;
        _secret.clear();
        _mustRestart = false;
        _phase = _Phase.verify;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _applyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Passkey: open the native prompt straight away; the verify step only offers a retry.
    if (mounted && started?.method == AccountDeletionMethod.passkey) {
      await _confirm();
    }
  }

  Future<void> _confirm() async {
    final token = _token;
    final challenge = _challenge;
    final secret = _secret.text.trim();
    final passkey = challenge?.method == AccountDeletionMethod.passkey;
    if (token == null || challenge == null || _busy) return;
    if (!passkey && secret.isEmpty) return;
    final repo = _repo;
    final platform = passkey ? context.read<PasskeyPlatform>() : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final assertion = await platform?.authenticate(
        challenge.passkeyOptions ?? const {},
      );
      final scheduled = await repo.confirm(
        accessToken: token,
        requestId: challenge.requestId,
        code: challenge.method == AccountDeletionMethod.phoneOtp
            ? secret
            : null,
        password: challenge.method == AccountDeletionMethod.password
            ? _secret.text
            : null,
        passkey: assertion,
      );
      if (!mounted) return;
      setState(() {
        _scheduled = scheduled;
        _phase = _Phase.done;
      });
    } on PasskeyPlatformException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      // Cancelling the system prompt is a choice, not an error: stay quiet.
      setState(
        () => _error = switch (error.kind) {
          PasskeyFailureKind.cancelled => null,
          PasskeyFailureKind.unsupported => l10n.securityPasskeyUnsupported,
          _ => l10n.deleteAccountWrongPasskey,
        },
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _applyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyError(ApiException error) {
    final l10n = AppLocalizations.of(context);
    switch (error.errorCode) {
      case 'ACCOUNT_DELETION_BLOCKED':
        _blockers = decodeAccountDeletionBlockers(error.details?['blockers']);
        _phase = _Phase.form;
        _error = null;
      case 'ACCOUNT_DELETION_REAUTH_UNAVAILABLE':
        _error = l10n.deleteAccountReauthUnavailable;
      case 'AUTH_CODE_INVALID':
        _error = l10n.deleteAccountWrongCode;
      case 'AUTH_PASSWORD_INVALID':
        _error = l10n.deleteAccountWrongPassword;
      case 'AUTH_PASSKEY_INVALID':
        _error = l10n.deleteAccountWrongPasskey;
      case 'AUTH_CODE_LOCKED':
        _error = l10n.deleteAccountLocked;
        _mustRestart = true;
      case 'AUTH_CODE_EXPIRED' || 'ACCOUNT_DELETION_NOT_FOUND':
        _error = l10n.deleteAccountExpired;
        _mustRestart = true;
      default:
        _error = apiErrorText(l10n, error);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    await context.read<AuthCubit>().signOut(revokeRemote: false);
    if (!mounted) return;
    router.go(AuthRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _phase != _Phase.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _Phase.done) {
          _finish();
        }
      },
      child: Scaffold(
        backgroundColor: DealGoColors.card,
        appBar: DealGoAppHeader(
          applySafeArea: true,
          title: l10n.deleteAccountHeader,
          showBack: _phase != _Phase.done,
          onBack: _phase == _Phase.verify && !_busy
              ? () => setState(() {
                  _phase = _Phase.form;
                  _error = null;
                })
              : null,
        ),
        body: SafeArea(
          top: false,
          child: switch (_phase) {
            _Phase.loading => const Center(child: CircularProgressIndicator()),
            _Phase.loadError => _LoadError(onRetry: _load),
            _Phase.form => _buildForm(context),
            _Phase.verify => _buildVerify(context),
            _Phase.done => _buildDone(context),
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final overview = _overview!;
    final noJobs = _blockers.isEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('delete-account-form'),
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              Text(
                l10n.deleteAccountTitle,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              _WarningBox(
                title: l10n.deleteAccountWarnTitle,
                body: l10n.deleteAccountWarnBody,
              ),
              const SizedBox(height: DealGoSpacing.s20),
              Text(l10n.deleteAccountWhatHappens, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              _Group(
                children: [
                  _ConsequenceRow(
                    icon: DealGoIcons.lock,
                    tone: DealGoBadgeTone.danger,
                    title: l10n.deleteAccountNoLoginTitle,
                    body: l10n.deleteAccountNoLoginBody,
                  ),
                  _ConsequenceRow(
                    icon: DealGoIcons.document,
                    tone: DealGoBadgeTone.brand,
                    title: l10n.deleteAccountDataTitle,
                    body: l10n.deleteAccountDataBody(overview.graceDays),
                  ),
                  _ConsequenceRow(
                    icon: DealGoIcons.receipt,
                    tone: DealGoBadgeTone.amber,
                    title: l10n.deleteAccountHistoryTitle,
                    body: l10n.deleteAccountHistoryBody,
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s20),
              Text(l10n.deleteAccountBefore, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              _Group(
                children: [
                  _CheckRow(
                    key: const ValueKey('delete-check-jobs'),
                    label: l10n.deleteAccountCheckNoJobs,
                    checked: noJobs,
                    onChanged: null,
                    details: [
                      for (final b in _blockers) deletionBlockerText(l10n, b),
                    ],
                  ),
                  _CheckRow(
                    key: const ValueKey('delete-check-backup'),
                    label: l10n.deleteAccountCheckBackup,
                    checked: _backedUp,
                    onChanged: (value) => setState(() => _backedUp = value),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s20),
              Text(l10n.deleteAccountTypeLabel, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s8),
              DealGoTextField(
                fieldKey: const ValueKey('delete-confirm-word'),
                label: l10n.deleteAccountTypeLabel,
                showLabel: false,
                hint: l10n.deleteAccountTypeHint,
                controller: _word,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              if (overview.method == null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                _ErrorText(l10n.deleteAccountReauthUnavailable),
              ],
              if (_error != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                _ErrorText(_error!),
              ],
            ],
          ),
        ),
        _Footer(
          primary: _DangerButton(
            key: const ValueKey('delete-continue'),
            label: l10n.deleteAccountContinue,
            busy: _busy,
            onPressed: _canContinue ? _start : null,
          ),
          secondary: DealGoSecondaryButton(
            label: l10n.deleteAccountKeep,
            onPressed: () => context.pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildVerify(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final challenge = _challenge!;
    if (challenge.method == AccountDeletionMethod.passkey) {
      return _buildPasskeyVerify(context);
    }
    final otp = challenge.method == AccountDeletionMethod.phoneOtp;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('delete-account-verify'),
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              Text(
                l10n.deleteAccountVerifyTitle,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                otp
                    ? l10n.deleteAccountCodeBody(challenge.phoneMasked ?? '')
                    : l10n.deleteAccountPasswordBody,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: DealGoSpacing.s20),
              DealGoTextField(
                fieldKey: const ValueKey('delete-secret'),
                label: otp
                    ? l10n.deleteAccountCodeLabel
                    : l10n.deleteAccountPasswordLabel,
                controller: _secret,
                obscure: !otp,
                autofocus: true,
                enabled: !_mustRestart,
                keyboardType: otp
                    ? TextInputType.number
                    : TextInputType.visiblePassword,
                autofillHints: otp
                    ? const [AutofillHints.oneTimeCode]
                    : const [AutofillHints.password],
                inputFormatters: otp
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ]
                    : null,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirm(),
              ),
              if (_error != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                _ErrorText(_error!),
              ],
            ],
          ),
        ),
        _Footer(
          primary: _mustRestart
              ? _DangerButton(
                  key: const ValueKey('delete-restart'),
                  label: l10n.deleteAccountRestart,
                  busy: _busy,
                  onPressed: _start,
                )
              : _DangerButton(
                  key: const ValueKey('delete-confirm'),
                  label: l10n.deleteAccountConfirm,
                  busy: _busy,
                  onPressed: _secret.text.trim().isEmpty ? null : _confirm,
                ),
          secondary: DealGoSecondaryButton(
            label: l10n.deleteAccountKeep,
            onPressed: () => context.pop(),
          ),
        ),
      ],
    );
  }

  /// No text field: the system prompt does the work, the page only offers a retry.
  Widget _buildPasskeyVerify(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('delete-account-verify'),
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              Text(
                l10n.deleteAccountVerifyTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                _ErrorText(_error!),
              ],
            ],
          ),
        ),
        _Footer(
          primary: _mustRestart
              ? _DangerButton(
                  key: const ValueKey('delete-restart'),
                  label: l10n.deleteAccountRestart,
                  busy: _busy,
                  onPressed: _start,
                )
              : _DangerButton(
                  key: const ValueKey('delete-passkey'),
                  label: l10n.deleteAccountPasskeyVerify,
                  busy: _busy,
                  onPressed: _confirm,
                ),
          secondary: DealGoSecondaryButton(
            label: l10n.deleteAccountKeep,
            onPressed: () => context.pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat(
      'HH:mm dd/MM/yyyy',
      locale,
    ).format(_scheduled!.purgeAfter);
    return Padding(
      key: const ValueKey('delete-account-done'),
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      child: Column(
        children: [
          const Spacer(),
          const DealGoIconBadge(
            DealGoIcons.check,
            tone: DealGoBadgeTone.green,
            size: 72,
            circle: true,
          ),
          const SizedBox(height: DealGoSpacing.s20),
          Text(
            l10n.deleteAccountDoneTitle,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(
            l10n.deleteAccountDoneBody(date),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: DealGoSecondaryButton(
              key: const ValueKey('delete-done'),
              label: l10n.deleteAccountDoneAction,
              onPressed: _finish,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.deleteAccountLoadError, textAlign: TextAlign.center),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoSecondaryButton(label: l10n.actionRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.dangerSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.danger.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(DealGoIcons.alert, color: DealGoColors.danger, size: 20),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      color: DealGoColors.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.danger,
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

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: DealGoColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ConsequenceRow extends StatelessWidget {
  const _ConsequenceRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final DealGoBadgeTone tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(DealGoSpacing.s12),
      child: Row(
        children: [
          DealGoIconBadge(icon, tone: tone),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.details = const [],
    super.key,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final change = onChanged;
    return InkWell(
      onTap: change == null ? null : () => change(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: checked,
                  onChanged: change == null
                      ? null
                      : (value) => change(value ?? false),
                  activeColor: DealGoColors.primary,
                  fillColor: change == null && checked
                      ? const WidgetStatePropertyAll(DealGoColors.primary)
                      : null,
                ),
                const SizedBox(width: DealGoSpacing.s4),
                Expanded(child: Text(label, style: textTheme.titleSmall)),
              ],
            ),
            for (final line in details)
              Padding(
                padding: const EdgeInsets.only(
                  left: 48,
                  bottom: DealGoSpacing.s4,
                ),
                child: Text(
                  line,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: DealGoColors.danger),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
      ),
      child: Row(
        children: [
          Expanded(child: secondary),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(child: primary),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DealGoDimensions.buttonMinHeight,
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: DealGoColors.danger,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DealGoColors.danger.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DealGoRadius.button),
          ),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
