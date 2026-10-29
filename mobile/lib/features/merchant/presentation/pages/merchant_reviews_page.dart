import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_card/presentation/driver_card_tile.dart'
    show formatRatingAverage;
import '../../../rating/domain/service_rating.dart';
import '../../../rating/presentation/rate_service_card.dart'
    show ratingTagLabel;
import '../widgets/merchant_widgets.dart';

/// M031 — customer reviews of the merchant's store, with a public reply.
class MerchantReviewsPage extends StatefulWidget {
  const MerchantReviewsPage({super.key});

  @override
  State<MerchantReviewsPage> createState() => _MerchantReviewsPageState();
}

class _MerchantReviewsPageState extends State<MerchantReviewsPage> {
  MerchantReviews? _data;
  Object? _error;
  var _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await context.read<RatingRepository>().merchantReviews(
        accessToken: merchantAccessToken(context) ?? '',
      );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _more() async {
    final data = _data;
    if (data == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await context.read<RatingRepository>().merchantReviews(
        accessToken: merchantAccessToken(context) ?? '',
        page: data.page + 1,
      );
      if (!mounted) return;
      setState(
        () => _data = MerchantReviews(
          summary: data.summary,
          items: [...data.items, ...next.items],
          total: next.total,
          page: next.page,
        ),
      );
    } catch (_) {
      // Keep what is shown; the button stays to retry.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _reply(StoreReview review) async {
    final updated = await showDealGoSheet<StoreReview>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => RepositoryProvider.value(
        value: context.read<RatingRepository>(),
        child: _ReplySheet(
          review: review,
          accessToken: merchantAccessToken(context) ?? '',
        ),
      ),
    );
    final data = _data;
    if (updated == null || data == null || !mounted) return;
    setState(
      () => _data = MerchantReviews(
        summary: data.summary,
        items: [for (final r in data.items) r.id == updated.id ? updated : r],
        total: data.total,
        page: data.page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final data = _data;
    final Widget body;
    if (_error != null && data == null) {
      body = DealGoStateView.failure(
        context,
        onRetry: _load,
        cause: _error,
        message: apiErrorText(l10n, _error),
      );
    } else if (data == null) {
      body = const DealGoSkeletonList(itemCount: 3);
    } else {
      final average = data.summary.average;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          children: [
            MerchantPanel(
              key: const Key('merchant-reviews-summary'),
              child: Row(
                children: [
                  const Icon(DealGoIcons.starFilled, color: DealGoColors.amber),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      average == null
                          ? l10n.storeRatingFew(data.summary.count)
                          : l10n.foodStoreReviewsSummary(
                              formatRatingAverage(context, average),
                              data.summary.count,
                            ),
                      style: textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            if (data.items.isEmpty) ...[
              const SizedBox(height: DealGoSpacing.s24),
              Center(
                child: Text(
                  l10n.merchantReviewsEmpty,
                  key: const Key('merchant-reviews-empty'),
                ),
              ),
            ],
            for (final (index, review) in data.items.indexed) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DealGoStaggerIn(
                index: index,
                child: _ReviewCard(
                  review: review,
                  onReply: () => _reply(review),
                ),
              ),
            ],
            if (data.hasMore) ...[
              const SizedBox(height: DealGoSpacing.s12),
              Center(
                child: OutlinedButton(
                  key: const Key('merchant-reviews-more'),
                  onPressed: _loadingMore ? null : _more,
                  child: Text(l10n.foodStoreReviewsMore),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return MerchantPageFrame(
      title: l10n.merchantReviewsTitle,
      onBack: () => merchantBack(context),
      body: body,
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReply});

  final StoreReview review;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final reply = review.merchantReply;
    return MerchantPanel(
      key: Key('merchant-review-${review.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  DealGoIcons.starFilled,
                  size: 14,
                  color: i < review.stars
                      ? DealGoColors.amber
                      : DealGoColors.border,
                ),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                DateFormat('dd/MM/yyyy').format(review.createdAt),
                style: textTheme.labelSmall,
              ),
              const Spacer(),
              if (review.hidden)
                MerchantChip(
                  key: Key('merchant-review-hidden-${review.id}'),
                  label: l10n.merchantReviewHidden,
                  tone: MerchantChipTone.warning,
                ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Wrap(
              spacing: DealGoSpacing.s6,
              runSpacing: DealGoSpacing.s6,
              children: [
                for (final tag in review.tags)
                  MerchantChip(
                    label: ratingTagLabel(l10n, tag),
                    tone: MerchantChipTone.neutral,
                  ),
              ],
            ),
          ],
          if (review.comment != null) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Text(review.comment!, style: textTheme.bodyMedium),
          ],
          if (reply != null) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DealGoSpacing.s12),
              decoration: BoxDecoration(
                color: DealGoColors.lavender,
                borderRadius: BorderRadius.circular(DealGoRadius.input),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.foodStoreMerchantReply,
                    style: textTheme.labelMedium?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(reply, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
          const SizedBox(height: DealGoSpacing.s8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('merchant-review-reply-${review.id}'),
              onPressed: onReply,
              icon: const Icon(DealGoIcons.chat, size: 16),
              label: Text(
                reply == null
                    ? l10n.merchantReviewReply
                    : l10n.merchantReviewEditReply,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.review, required this.accessToken});

  final StoreReview review;
  final String accessToken;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final _text = TextEditingController(text: widget.review.merchantReply);
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<RatingRepository>().replyToReview(
        accessToken: widget.accessToken,
        reviewId: widget.review.id,
        text: text,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorText(l10n, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasReply = widget.review.merchantReply != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasReply
                  ? l10n.merchantReviewEditReply
                  : l10n.merchantReviewReply,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              label: l10n.merchantReviewReply,
              showLabel: false,
              controller: _text,
              fieldKey: const Key('merchant-review-reply-text'),
              maxLines: 4,
              maxLength: 500,
              autofocus: true,
              errorText: _error,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasReply) ...[
                    Expanded(
                      child: DealGoSecondaryButton(
                        key: const Key('merchant-review-reply-remove'),
                        tone: DealGoSecondaryTone.danger,
                        label: l10n.merchantReviewReplyRemove,
                        enabled: !_saving,
                        onPressed: () => _send(''),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                  ],
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: _text,
                      builder: (context, value, _) => DealGoPrimaryButton(
                        key: const Key('merchant-review-reply-send'),
                        label: l10n.merchantReviewReplySend,
                        isLoading: _saving,
                        enabled: !_saving && value.text.trim().isNotEmpty,
                        onPressed: () => _send(_text.text),
                      ),
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
