import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/network/request_failure.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../shell/presentation/account_routes.dart';
import '../../shell/presentation/account_widgets.dart';
import '../domain/support_ticket.dart';
import 'support_copy.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';

/// S022 — the signed-in user's support requests.
class SupportTicketsPage extends StatefulWidget {
  const SupportTicketsPage({required this.shellPath, super.key});

  final String shellPath;

  @override
  State<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends State<SupportTicketsPage> {
  SupportListFilter _filter = SupportListFilter.all;
  SupportTicketPage? _page;
  var _loading = true;
  Object? _failure;

  String? get _token {
    final auth = context.read<AuthCubit>().state;
    return auth is AuthSignedIn ? auth.tokens.accessToken : null;
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
        _failure = sessionExpiredFailure;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page = await context.read<SupportRepository>().list(
        accessToken: token,
        filter: _filter,
      );
      if (mounted) {
        setState(() {
          _page = page;
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

  Future<void> _create() async {
    final created = await context.push<bool>(
      AccountRoutes.supportTicketNew(widget.shellPath),
    );
    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _open(SupportTicket ticket) async {
    await context.push(
      AccountRoutes.supportTicket(widget.shellPath, ticket.id),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final page = _page;
    final active = page?.activeCount ?? 0;
    final done = page?.doneCount ?? 0;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(
              title: l10n.supportListTitle,
              actions: IconButton(
                key: const Key('support-new-icon'),
                tooltip: l10n.supportNewTicket,
                onPressed: _create,
                icon: const Icon(DealGoIcons.add, color: DealGoColors.primary),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s16,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s16,
                  ),
                  children: [
                    Text(
                      l10n.supportListHeading,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (filter, label) in [
                            (
                              SupportListFilter.all,
                              l10n.supportFilterAll(active + done),
                            ),
                            (
                              SupportListFilter.active,
                              l10n.supportFilterActive(active),
                            ),
                            (
                              SupportListFilter.done,
                              l10n.supportFilterDone(done),
                            ),
                          ]) ...[
                            AccountFilterChip(
                              key: Key('support-filter-${filter.name}'),
                              label: label,
                              selected: _filter == filter,
                              onSelected: () {
                                if (_filter == filter) return;
                                setState(() => _filter = filter);
                                _load();
                              },
                            ),
                            const SizedBox(width: DealGoSpacing.s8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    if (_loading && page == null)
                      const DealGoSkeletonList(itemCount: 3)
                    else if (_failure != null)
                      DealGoStateView.failure(
                        context,
                        onRetry: _load,
                        cause: _failure,
                        message: l10n.supportListLoadFailed,
                        compact: true,
                      )
                    else if (page == null || page.items.isEmpty)
                      DealGoStateView(
                        art: DealGoStateArt.noMessages,
                        title: l10n.supportListEmptyTitle,
                        message: l10n.supportListEmptyBody,
                        compact: true,
                      )
                    else
                      for (final ticket in page.items) ...[
                        _TicketCard(ticket: ticket, onTap: () => _open(ticket)),
                        const SizedBox(height: DealGoSpacing.s12),
                      ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: DealGoPrimaryButton(
                key: const Key('support-new-button'),
                label: l10n.supportNewTicket,
                onPressed: _create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final chip = supportStatusChip(l10n, ticket);
    return DealGoCard(
      key: Key('support-ticket-${ticket.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.code,
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              DealGoChip(
                label: chip.label,
                tone: chip.tone,
                size: DealGoChipSize.sm,
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Text(ticket.subject, style: textTheme.titleMedium),
          if (ticket.preview != null) ...[
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              ticket.preview!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
          const Divider(height: DealGoSpacing.s24),
          Row(
            children: [
              Icon(
                supportCategoryIcon(ticket.category),
                size: 14,
                color: DealGoColors.textSecondary,
              ),
              const SizedBox(width: DealGoSpacing.s4),
              Text(
                supportCategoryLabel(l10n, ticket.category),
                style: textTheme.bodySmall,
              ),
              const SizedBox(width: DealGoSpacing.s16),
              Icon(
                DealGoIcons.clock,
                size: 14,
                color: DealGoColors.textSecondary,
              ),
              const SizedBox(width: DealGoSpacing.s4),
              Expanded(
                child: Text(
                  supportTime(context, ticket.lastMessageAt),
                  style: textTheme.bodySmall,
                ),
              ),
              Icon(
                DealGoIcons.chevronRight,
                size: 18,
                color: DealGoColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
