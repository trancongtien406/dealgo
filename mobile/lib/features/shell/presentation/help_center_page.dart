import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_bottom_bar.dart';
import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../support/domain/help_faq.dart';
import '../../support/domain/support_ticket.dart';
import 'account_routes.dart';
import 'account_widgets.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';

enum _HelpTopic { ride, food, payment, account }

/// Help audience for the shell the page is opened from (DEC-PROD-021).
String helpAudienceFor(String shellPath) {
  if (shellPath.startsWith('/driver')) return 'DRIVER';
  if (shellPath.startsWith('/merchant')) return 'MERCHANT';
  return 'CUSTOMER';
}

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({required this.shellPath, super.key});

  final String shellPath;

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _open = <String>{};
  _HelpTopic? _topic;
  List<HelpFaq>? _faqs;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    HelpFaqRepository? repository;
    try {
      repository = context.read<HelpFaqRepository>();
    } on Object {
      repository = null;
    }
    if (repository == null) {
      setState(() => _faqs = const []);
      return;
    }
    setState(() {
      _failure = null;
      _faqs = null;
    });
    try {
      final items = await repository.list(
        audience: helpAudienceFor(widget.shellPath),
      );
      if (mounted) setState(() => _faqs = items);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failure = error;
          _faqs = const [];
        });
      }
    }
  }

  bool _visible(HelpFaq faq) {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return faq.question.toLowerCase().contains(query) ||
        faq.answer.toLowerCase().contains(query);
  }

  void _toggle(String id) {
    setState(() {
      if (!_open.add(id)) {
        _open.remove(id);
      }
    });
  }

  SupportCategory get _categoryForTopic => switch (_topic) {
    _HelpTopic.ride => SupportCategory.ride,
    _HelpTopic.food => SupportCategory.food,
    _HelpTopic.payment => SupportCategory.payment,
    _HelpTopic.account => SupportCategory.account,
    null => SupportCategory.other,
  };

  void _openTickets() =>
      context.push(AccountRoutes.supportTickets(widget.shellPath));

  Future<void> _createTicket() async {
    final created = await context.push<bool>(
      AccountRoutes.supportTicketNew(widget.shellPath),
      extra: _categoryForTopic,
    );
    if (created == true && mounted) {
      _openTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final faqs = _faqs;
    final visible = [
      for (final faq in faqs ?? const <HelpFaq>[])
        if (_visible(faq)) faq,
    ];
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(
              title: l10n.helpTitle,
              actions: IconButton(
                key: const Key('help-open-tickets'),
                tooltip: l10n.helpMyTickets,
                onPressed: _openTickets,
                icon: const Icon(DealGoIcons.headset, color: DealGoColors.text),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24 +
                      DealGoDimensions.buttonMinHeight +
                      DealGoSpacing.s48,
                ),
                children: [
                  const _SupportBanner(),
                  const SizedBox(height: DealGoSpacing.s16),
                  DealGoTextField(
                    label: l10n.helpSearchHint,
                    showLabel: false,
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    prefixIcon: DealGoIcons.search,
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  Text(l10n.helpTopicsTitle, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  _TopicGrid(
                    selected: _topic,
                    onSelected: (topic) => setState(() {
                      _topic = _topic == topic ? null : topic;
                    }),
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  AccountSectionHeader(
                    title: l10n.helpFaqTitle,
                    action: TextButton(
                      onPressed: () => setState(() {
                        _query.clear();
                        _open.clear();
                      }),
                      child: AccountLinkText(l10n.helpSeeAll),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  if (faqs == null)
                    const DealGoSkeletonList(
                      key: Key('help-faq-loading'),
                      itemCount: 3,
                      padding: EdgeInsets.zero,
                    )
                  else if (_failure != null)
                    DealGoStateView.failure(
                      context,
                      key: const Key('help-faq-error'),
                      onRetry: _load,
                      cause: _failure,
                      message: l10n.helpFaqLoadFailed,
                      compact: true,
                    )
                  else if (faqs.isEmpty)
                    DealGoStateView(
                      key: const Key('help-faq-empty'),
                      art: DealGoStateArt.noMessages,
                      title: l10n.helpFaqEmpty,
                      compact: true,
                    )
                  else if (visible.isEmpty)
                    Text(
                      AppLocalizations.of(context).helpNoResults,
                      style: textTheme.bodyMedium,
                    )
                  else
                    for (final faq in visible) ...[
                      _FaqCard(
                        key: Key('help-faq-${faq.id}'),
                        faq: faq,
                        open: _open.contains(faq.id),
                        onTap: () => _toggle(faq.id),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                  const SizedBox(height: DealGoSpacing.s8),
                  DealGoCard(
                    key: const Key('help-still-need'),
                    onTap: _openTickets,
                    child: Row(
                      children: [
                        const AccountToneIcon(
                          icon: DealGoIcons.headset,
                          background: DealGoColors.subtlePurple,
                          foreground: DealGoColors.primary,
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.helpStillNeedTitle,
                                style: textTheme.titleMedium?.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.helpStillNeedBody,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          DealGoIcons.chevronRight,
                          color: DealGoColors.textSecondary,
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
      bottomNavigationBar: DealGoBottomBar(
        child: DealGoPrimaryButton(
          key: const Key('help-create-ticket'),
          label: l10n.helpCreateTicket,
          trailingIcon: DealGoIcons.arrowRight,
          onPressed: _createTicket,
        ),
      ),
    );
  }
}

class _SupportBanner extends StatelessWidget {
  const _SupportBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        color: DealGoColors.primary,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoSpacing.s12,
                        vertical: DealGoSpacing.s4,
                      ),
                      child: Text(
                        AppLocalizations.of(context).helpBannerBadge,
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    AppLocalizations.of(context).helpSubtitle,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(DealGoRadius.input),
              ),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(DealGoIcons.headset, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({required this.selected, required this.onSelected});

  final _HelpTopic? selected;
  final ValueChanged<_HelpTopic> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.ride,
                selected: selected == _HelpTopic.ride,
                icon: DealGoIcons.car,
                title: l10n.helpTopicRide,
                onSelected: onSelected,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.food,
                selected: selected == _HelpTopic.food,
                icon: DealGoIcons.restaurant,
                title: l10n.helpTopicFood,
                onSelected: onSelected,
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.payment,
                selected: selected == _HelpTopic.payment,
                icon: DealGoIcons.wallet,
                title: l10n.helpTopicPayment,
                onSelected: onSelected,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _TopicCard(
                topic: _HelpTopic.account,
                selected: selected == _HelpTopic.account,
                icon: DealGoIcons.shieldPlain,
                title: l10n.helpTopicAccount,
                onSelected: onSelected,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onSelected,
  });

  final _HelpTopic topic;
  final bool selected;
  final IconData icon;
  final String title;
  final ValueChanged<_HelpTopic> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      onTap: () => onSelected(topic),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountToneIcon(
            icon: icon,
            background: DealGoColors.subtlePurple,
            foreground: DealGoColors.primary,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(title, style: textTheme.titleMedium?.copyWith(fontSize: 16)),
          if (selected) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              AppLocalizations.of(context).helpTopicSelected,
              style: textTheme.labelSmall?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.faq,
    required this.open,
    required this.onTap,
    super.key,
  });

  final HelpFaq faq;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccountToneIcon(
                icon: DealGoIcons.help,
                background: DealGoColors.subtlePurple,
                foreground: DealGoColors.primary,
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Text(
                  faq.question,
                  style: textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
              ),
              Icon(
                open ? DealGoIcons.expandLess : DealGoIcons.chevronRight,
                color: DealGoColors.textSecondary,
              ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: DealGoSpacing.s12),
            Text(faq.answer, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
