import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/request_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/support_ticket.dart';
import '../../onboarding/presentation/document_image_source.dart';
import 'support_attachments.dart';
import 'support_copy.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';

/// S023 — one support request: info, real progress timestamps and the thread.
class SupportTicketDetailPage extends StatefulWidget {
  const SupportTicketDetailPage({required this.ticketId, super.key});

  final String ticketId;

  @override
  State<SupportTicketDetailPage> createState() =>
      _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends State<SupportTicketDetailPage> {
  final _reply = TextEditingController();
  SupportTicket? _ticket;
  var _loading = true;
  Object? _failure;
  var _sending = false;
  String? _sendError;
  var _photos = <PickedDocumentImage>[];

  String? get _token {
    final auth = context.read<AuthCubit>().state;
    return auth is AuthSignedIn ? auth.tokens.accessToken : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) {
      setState(() {
        _loading = false;
        _failure = sessionExpiredFailure;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final ticket = await context.read<SupportRepository>().get(
        accessToken: token,
        id: widget.ticketId,
      );
      if (mounted) {
        setState(() {
          _ticket = ticket;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = error;
        });
      }
    }
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final body = _reply.text.trim();
    final token = _token;
    if (body.isEmpty || token == null || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final ticket = await context.read<SupportRepository>().addMessage(
        accessToken: token,
        id: widget.ticketId,
        body: body,
        attachments: supportUploads(_photos),
      );
      if (!mounted) return;
      _reply.clear();
      setState(() {
        _ticket = ticket;
        _sending = false;
        _photos = [];
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError =
            supportUploadErrorText(l10n, error) ??
            switch (error.errorCode) {
              'SUPPORT_TICKET_CLOSED' => l10n.supportClosedNote,
              'SUPPORT_TEXT_TOO_LONG' => l10n.supportTextTooLong,
              _ => l10n.supportSendFailed,
            };
      });
      if (error.errorCode == 'SUPPORT_TICKET_CLOSED') {
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ticket = _ticket;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(title: l10n.supportDetailTitle),
            Expanded(
              child: ticket == null
                  ? (_loading
                        ? const Center(child: CircularProgressIndicator())
                        : DealGoStateView.failure(
                            context,
                            onRetry: _load,
                            cause: _failure,
                            message: l10n.supportDetailLoadFailed,
                          ))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _TicketBody(
                        ticket: ticket,
                        failed: _failure != null,
                      ),
                    ),
            ),
            if (ticket != null) _composer(context, l10n, ticket),
          ],
        ),
      ),
    );
  }

  Widget _composer(
    BuildContext context,
    AppLocalizations l10n,
    SupportTicket ticket,
  ) {
    final textTheme = Theme.of(context).textTheme;
    if (ticket.status == SupportStatus.closed) {
      return Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Text(
          l10n.supportClosedNote,
          key: const Key('support-closed-note'),
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }
    return Material(
      color: DealGoColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s16,
          DealGoSpacing.s8,
          DealGoSpacing.s8,
          DealGoSpacing.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ticket.status == SupportStatus.resolved)
              Padding(
                padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
                child: Text(
                  l10n.supportResolvedNote,
                  style: textTheme.bodySmall,
                ),
              ),
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
                child: Text(
                  _sendError!,
                  key: const Key('support-send-error'),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.danger,
                  ),
                ),
              ),
            if (supportImageSource(context) case final source?)
              SupportAttachmentPicker(
                source: source,
                picked: _photos,
                compact: true,
                enabled: !_sending,
                onChanged: (next) => setState(() => _photos = next),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DealGoTextField(
                    fieldKey: const Key('support-reply-field'),
                    label: l10n.supportReplyHint,
                    showLabel: false,
                    controller: _reply,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                IconButton.filled(
                  key: const Key('support-reply-send'),
                  tooltip: l10n.supportReplySend,
                  onPressed: _sending ? null : _send,
                  icon: const Icon(DealGoIcons.send, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketBody extends StatelessWidget {
  const _TicketBody({required this.ticket, required this.failed});

  final SupportTicket ticket;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final chip = supportStatusChip(l10n, ticket);
    final related = supportRelatedLabel(l10n, ticket);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: DealGoChip(
            key: const Key('support-status-chip'),
            label: chip.label,
            tone: chip.tone,
            size: DealGoChipSize.sm,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(ticket.subject, style: textTheme.headlineSmall),
        const SizedBox(height: DealGoSpacing.s4),
        Text(
          l10n.supportCodeCreated(
            ticket.code,
            supportTime(context, ticket.createdAt),
          ),
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        DealGoCard(
          child: Column(
            children: [
              _InfoRow(
                label: l10n.supportInfoCategory,
                value: supportCategoryLabel(l10n, ticket.category),
              ),
              if (related != null)
                _InfoRow(label: l10n.supportInfoRelated, value: related),
              _InfoRow(
                label: l10n.supportInfoPriority,
                value: supportPriorityLabel(l10n, ticket.priority),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s20),
        Text(l10n.supportProgressTitle, style: textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s12),
        ..._progress(context, l10n),
        const SizedBox(height: DealGoSpacing.s20),
        Text(l10n.supportThreadTitle, style: textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s12),
        for (final message in ticket.messages) ...[
          _Bubble(message: message, ticketId: ticket.id),
          const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }

  /// Steps come from real timestamps only; a step without one is not shown as done.
  List<Widget> _progress(BuildContext context, AppLocalizations l10n) {
    final steps = <({String title, String? body, bool done})>[
      (
        title: l10n.supportProgressReceived,
        body: l10n.supportProgressReceivedAt(
          supportTime(context, ticket.createdAt),
        ),
        done: true,
      ),
      if (ticket.status != SupportStatus.open)
        (
          title: l10n.supportProgressInProgress,
          body: l10n.supportProgressInProgressBody,
          done: ticket.status != SupportStatus.inProgress,
        ),
      if (ticket.resolvedAt != null)
        (
          title: l10n.supportProgressResolved,
          body: l10n.supportProgressAt(
            supportTime(context, ticket.resolvedAt!),
          ),
          done: true,
        ),
      if (ticket.closedAt != null)
        (
          title: l10n.supportProgressClosed,
          body: l10n.supportProgressAt(supportTime(context, ticket.closedAt!)),
          done: true,
        ),
    ];
    final textTheme = Theme.of(context).textTheme;
    return [
      for (final step in steps)
        Padding(
          padding: const EdgeInsets.only(bottom: DealGoSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                step.done ? DealGoIcons.check : DealGoIcons.clock,
                size: 18,
                color: step.done
                    ? DealGoColors.brandGreen
                    : DealGoColors.primary,
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: textTheme.titleSmall),
                    if (step.body != null)
                      Text(step.body!, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodySmall)),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.ticketId});

  final SupportMessage message;
  final String ticketId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final staff = message.fromStaff;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.all(DealGoSpacing.s12),
      decoration: BoxDecoration(
        color: staff ? DealGoColors.card : DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: staff ? Border.all(color: DealGoColors.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (staff)
            Text(
              l10n.supportStaffName,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          Text(message.body, style: textTheme.bodyMedium),
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s8),
            SupportAttachmentList(ticketId: ticketId, message: message),
          ],
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            supportTime(context, message.createdAt),
            style: textTheme.labelSmall?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
    return Row(
      mainAxisAlignment: staff
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (staff) ...[
          const CircleAvatar(
            radius: 16,
            backgroundColor: DealGoColors.subtlePurple,
            child: Text(
              'DG',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: DealGoColors.primary,
              ),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
        ],
        bubble,
      ],
    );
  }
}
