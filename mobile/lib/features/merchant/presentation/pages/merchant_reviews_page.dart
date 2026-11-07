import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
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
import '../../../shell/presentation/account_widgets.dart';
import '../widgets/merchant_widgets.dart';

enum _DatePreset { all, today, past7Days, past30Days }

/// M031 — customer reviews of the merchant's store, with comprehensive filters and public reply.
class MerchantReviewsPage extends StatefulWidget {
  const MerchantReviewsPage({super.key});

  @override
  State<MerchantReviewsPage> createState() => _MerchantReviewsPageState();
}

class _MerchantReviewsPageState extends State<MerchantReviewsPage> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  MerchantReviews? _data;
  Object? _error;
  var _loadingMore = false;
  var _loadMoreFailed = false;
  var _hasSearchText = false;
  var _generation = 0;

  // Filter state
  int? _stars;
  MerchantReviewReplyFilter _replied = MerchantReviewReplyFilter.all;
  bool? _hasComment;
  MerchantReviewVisibilityFilter _visibility =
      MerchantReviewVisibilityFilter.all;
  RatingTag? _tag;
  _DatePreset _datePreset = _DatePreset.all;
  DateTimeRange? _customRange;
  MerchantReviewSort _sort = MerchantReviewSort.newest;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _search.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _search.removeListener(_onSearchChanged);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final hasText = _search.text.trim().isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() => _hasSearchText = hasText);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 400) return;
    final data = _data;
    if (data == null || !data.hasMore || _loadingMore || _loadMoreFailed) {
      return;
    }
    unawaited(_more());
  }

  bool get _hasActiveFilters =>
      _stars != null ||
      _replied != MerchantReviewReplyFilter.all ||
      _hasComment != null ||
      _visibility != MerchantReviewVisibilityFilter.all ||
      _tag != null ||
      _datePreset != _DatePreset.all ||
      _customRange != null ||
      _sort != MerchantReviewSort.newest;

  (DateTime?, DateTime?) _computeDateRange() {
    if (_customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return (
        DateTime(s.year, s.month, s.day),
        DateTime(e.year, e.month, e.day, 23, 59, 59, 999),
      );
    }
    final now = DateTime.now();
    return switch (_datePreset) {
      _DatePreset.all => (null, null),
      _DatePreset.today => (
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      ),
      _DatePreset.past7Days => (
        now.subtract(const Duration(days: 7)),
        now,
      ),
      _DatePreset.past30Days => (
        now.subtract(const Duration(days: 30)),
        now,
      ),
    };
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _stars = null;
      _replied = MerchantReviewReplyFilter.all;
      _hasComment = null;
      _visibility = MerchantReviewVisibilityFilter.all;
      _tag = null;
      _datePreset = _DatePreset.all;
      _customRange = null;
      _sort = MerchantReviewSort.newest;
    });
    _load();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    setState(() {
      _error = null;
      _loadMoreFailed = false;
    });
    final (from, to) = _computeDateRange();
    try {
      final data = await context.read<RatingRepository>().merchantReviews(
        accessToken: merchantAccessToken(context) ?? '',
        page: 1,
        stars: _stars,
        replied: _replied,
        hasComment: _hasComment,
        visibility: _visibility,
        tag: _tag,
        q: _search.text.trim().isEmpty ? null : _search.text.trim(),
        from: from,
        to: to,
        sort: _sort,
      );
      if (mounted && gen == _generation) {
        setState(() => _data = data);
      }
    } catch (error) {
      if (mounted && gen == _generation) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _more() async {
    final data = _data;
    if (data == null || _loadingMore) return;
    final gen = _generation;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    final (from, to) = _computeDateRange();
    try {
      final next = await context.read<RatingRepository>().merchantReviews(
        accessToken: merchantAccessToken(context) ?? '',
        page: data.page + 1,
        stars: _stars,
        replied: _replied,
        hasComment: _hasComment,
        visibility: _visibility,
        tag: _tag,
        q: _search.text.trim().isEmpty ? null : _search.text.trim(),
        from: from,
        to: to,
        sort: _sort,
      );
      if (!mounted || gen != _generation) return;
      setState(
        () => _data = MerchantReviews(
          summary: data.summary,
          items: [...data.items, ...next.items],
          total: next.total,
          page: next.page,
        ),
      );
    } catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted && gen == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _openFilterSheet() {
    showDealGoSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ReviewsFilterSheet(
        stars: _stars,
        replied: _replied,
        hasComment: _hasComment,
        visibility: _visibility,
        tag: _tag,
        datePreset: _datePreset,
        customRange: _customRange,
        sort: _sort,
        onApply: ({
          required int? stars,
          required MerchantReviewReplyFilter replied,
          required bool? hasComment,
          required MerchantReviewVisibilityFilter visibility,
          required RatingTag? tag,
          required _DatePreset datePreset,
          required DateTimeRange? customRange,
          required MerchantReviewSort sort,
        }) {
          setState(() {
            _stars = stars;
            _replied = replied;
            _hasComment = hasComment;
            _visibility = visibility;
            _tag = tag;
            _datePreset = datePreset;
            _customRange = customRange;
            _sort = sort;
          });
          _load();
        },
        onReset: _resetFilters,
      ),
    );
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
      body = DealGoRefresh(
        onRefresh: _load,
        child: DealGoStateView.failure(
          context,
          onRetry: _load,
          cause: _error,
          message: apiErrorText(l10n, _error),
        ),
      );
    } else if (data == null) {
      body = const DealGoSkeletonList(itemCount: 3);
    } else {
      final average = data.summary.average;
      final hasFiltersOrSearch = _hasActiveFilters || _hasSearchText;

      body = DealGoRefresh(
        onRefresh: _load,
        child: ListView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          children: [
            // 1. Search Bar
            DealGoTextField(
              label: l10n.merchantReviewsSearch,
              showLabel: false,
              hint: l10n.merchantReviewsSearch,
              controller: _search,
              fieldKey: const Key('merchant-reviews-search'),
              textInputAction: TextInputAction.search,
              prefixIcon: DealGoIcons.search,
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasSearchText)
                    IconButton(
                      key: const Key('merchant-reviews-search-clear'),
                      icon: const Icon(DealGoIcons.close, size: 18),
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                    ),
                  IconButton(
                    key: const Key('merchant-reviews-search-go'),
                    icon: const Icon(DealGoIcons.search),
                    tooltip: 'Tìm kiếm',
                    onPressed: _load,
                  ),
                ],
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: DealGoSpacing.s8),

            // 2. Horizontal Quick Filters Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AccountFilterChip(
                    key: const Key('merchant-reviews-tab-all'),
                    label: l10n.merchantReviewsFilterRepliedAll,
                    selected: _stars == null &&
                        _replied == MerchantReviewReplyFilter.all,
                    onSelected: () {
                      if (_stars == null &&
                          _replied == MerchantReviewReplyFilter.all) {
                        return;
                      }
                      setState(() {
                        _stars = null;
                        _replied = MerchantReviewReplyFilter.all;
                      });
                      _load();
                    },
                  ),
                  for (final star in [5, 4, 3, 2, 1]) ...[
                    const SizedBox(width: DealGoSpacing.s8),
                    AccountFilterChip(
                      key: Key('merchant-reviews-star-$star'),
                      icon: DealGoIcons.starFilled,
                      label: '$star',
                      selected: _stars == star,
                      onSelected: () {
                        setState(() => _stars = _stars == star ? null : star);
                        _load();
                      },
                    ),
                  ],
                  const SizedBox(width: DealGoSpacing.s8),
                  AccountFilterChip(
                    key: const Key('merchant-reviews-tab-unreplied'),
                    label: l10n.merchantReviewsFilterRepliedNo,
                    selected: _replied == MerchantReviewReplyFilter.unreplied,
                    onSelected: () {
                      setState(
                        () => _replied =
                            _replied == MerchantReviewReplyFilter.unreplied
                                ? MerchantReviewReplyFilter.all
                                : MerchantReviewReplyFilter.unreplied,
                      );
                      _load();
                    },
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  AccountFilterChip(
                    key: const Key('merchant-reviews-tab-replied'),
                    label: l10n.merchantReviewsFilterRepliedYes,
                    selected: _replied == MerchantReviewReplyFilter.replied,
                    onSelected: () {
                      setState(
                        () => _replied =
                            _replied == MerchantReviewReplyFilter.replied
                                ? MerchantReviewReplyFilter.all
                                : MerchantReviewReplyFilter.replied,
                      );
                      _load();
                    },
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  ActionChip(
                    key: const Key('merchant-reviews-open-filter-sheet'),
                    avatar: Icon(
                      DealGoIcons.filter,
                      size: 14,
                      color: _hasActiveFilters
                          ? DealGoColors.primary
                          : DealGoColors.textSecondary,
                    ),
                    label: Text(
                      _hasActiveFilters
                          ? l10n.merchantReviewsFilterActive
                          : l10n.merchantReviewsFilterTitle,
                      style: TextStyle(
                        color: _hasActiveFilters
                            ? DealGoColors.primary
                            : DealGoColors.text,
                        fontWeight: _hasActiveFilters
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    backgroundColor: _hasActiveFilters
                        ? DealGoColors.subtlePurple
                        : DealGoColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DealGoRadius.pill),
                      side: BorderSide(
                        color: _hasActiveFilters
                            ? DealGoColors.primary
                            : DealGoColors.border,
                      ),
                    ),
                    onPressed: _openFilterSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s8),

            // 3. Summary Panel
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

            // 4. Reset bar if filters are active
            if (hasFiltersOrSearch) ...[
              const SizedBox(height: DealGoSpacing.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${data.total} kết quả',
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('merchant-reviews-reset-filters'),
                    onPressed: _resetFilters,
                    icon: const Icon(DealGoIcons.close, size: 14),
                    label: Text(l10n.merchantReviewsFilterReset),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: DealGoColors.primary,
                    ),
                  ),
                ],
              ),
            ],

            // 5. Empty or Review List
            if (data.items.isEmpty) ...[
              const SizedBox(height: DealGoSpacing.s24),
              if (hasFiltersOrSearch)
                DealGoStateView(
                  key: const Key('merchant-reviews-empty-filtered'),
                  art: DealGoStateArt.noSearch,
                  title: l10n.merchantReviewsFilterNone,
                  actionLabel: l10n.merchantReviewsFilterReset,
                  onAction: _resetFilters,
                  compact: true,
                )
              else
                DealGoStateView(
                  key: const Key('merchant-reviews-empty'),
                  art: DealGoStateArt.noOrders,
                  title: l10n.merchantReviewsEmpty,
                  compact: true,
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
      trailing: IconButton(
        key: const Key('merchant-reviews-filter-button'),
        icon: Badge(
          isLabelVisible: _hasActiveFilters,
          child: const Icon(DealGoIcons.filter),
        ),
        tooltip: l10n.merchantReviewsFilterTitle,
        onPressed: _openFilterSheet,
      ),
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

class _ReviewsFilterSheet extends StatefulWidget {
  const _ReviewsFilterSheet({
    required this.stars,
    required this.replied,
    required this.hasComment,
    required this.visibility,
    required this.tag,
    required this.datePreset,
    required this.customRange,
    required this.sort,
    required this.onApply,
    required this.onReset,
  });

  final int? stars;
  final MerchantReviewReplyFilter replied;
  final bool? hasComment;
  final MerchantReviewVisibilityFilter visibility;
  final RatingTag? tag;
  final _DatePreset datePreset;
  final DateTimeRange? customRange;
  final MerchantReviewSort sort;
  final void Function({
    required int? stars,
    required MerchantReviewReplyFilter replied,
    required bool? hasComment,
    required MerchantReviewVisibilityFilter visibility,
    required RatingTag? tag,
    required _DatePreset datePreset,
    required DateTimeRange? customRange,
    required MerchantReviewSort sort,
  }) onApply;
  final VoidCallback onReset;

  @override
  State<_ReviewsFilterSheet> createState() => _ReviewsFilterSheetState();
}

class _ReviewsFilterSheetState extends State<_ReviewsFilterSheet> {
  late int? _stars = widget.stars;
  late MerchantReviewReplyFilter _replied = widget.replied;
  late bool? _hasComment = widget.hasComment;
  late MerchantReviewVisibilityFilter _visibility = widget.visibility;
  late RatingTag? _tag = widget.tag;
  late _DatePreset _datePreset = widget.datePreset;
  late DateTimeRange? _customRange = widget.customRange;
  late MerchantReviewSort _sort = widget.sort;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: DealGoColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _datePreset = _DatePreset.all;
        _customRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: DealGoDimensions.pageGutter,
        right: DealGoDimensions.pageGutter,
        top: DealGoSpacing.s16,
        bottom: bottomInset + DealGoSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.merchantReviewsFilterTitle,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(DealGoIcons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l10n.actionCancel,
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),

          // 1. Stars Filter
          Text(
            l10n.merchantReviewsFilterStars,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: l10n.merchantReviewsFilterRepliedAll,
                selected: _stars == null,
                onSelected: () => setState(() => _stars = null),
              ),
              for (final star in [5, 4, 3, 2, 1])
                AccountFilterChip(
                  icon: DealGoIcons.starFilled,
                  label: '$star',
                  selected: _stars == star,
                  onSelected: () => setState(
                    () => _stars = _stars == star ? null : star,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),

          // 2. Reply Status
          Text(
            l10n.merchantReviewsFilterReplied,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: l10n.merchantReviewsFilterRepliedAll,
                selected: _replied == MerchantReviewReplyFilter.all,
                onSelected: () => setState(
                  () => _replied = MerchantReviewReplyFilter.all,
                ),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterRepliedNo,
                selected: _replied == MerchantReviewReplyFilter.unreplied,
                onSelected: () => setState(
                  () => _replied = MerchantReviewReplyFilter.unreplied,
                ),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterRepliedYes,
                selected: _replied == MerchantReviewReplyFilter.replied,
                onSelected: () => setState(
                  () => _replied = MerchantReviewReplyFilter.replied,
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),

          // 3. Comment Filter
          Text(
            l10n.merchantReviewsFilterComment,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: l10n.merchantReviewsFilterCommentAll,
                selected: _hasComment == null,
                onSelected: () => setState(() => _hasComment = null),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterCommentOnly,
                selected: _hasComment == true,
                onSelected: () => setState(
                  () => _hasComment = _hasComment == true ? null : true,
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),

          // 4. Moderation Visibility
          Text(
            l10n.merchantReviewsFilterVisibility,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: l10n.merchantReviewsFilterVisAll,
                selected: _visibility == MerchantReviewVisibilityFilter.all,
                onSelected: () => setState(
                  () => _visibility = MerchantReviewVisibilityFilter.all,
                ),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterVisVisible,
                selected: _visibility == MerchantReviewVisibilityFilter.visible,
                onSelected: () => setState(
                  () => _visibility = MerchantReviewVisibilityFilter.visible,
                ),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterVisHidden,
                selected: _visibility == MerchantReviewVisibilityFilter.hidden,
                onSelected: () => setState(
                  () => _visibility = MerchantReviewVisibilityFilter.hidden,
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),

          // 5. Tags Filter
          Text(
            l10n.merchantReviewsFilterTags,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: l10n.merchantReviewsFilterTagAll,
                selected: _tag == null,
                onSelected: () => setState(() => _tag = null),
              ),
              for (final t in RatingTag.values)
                AccountFilterChip(
                  label: ratingTagLabel(l10n, t),
                  selected: _tag == t,
                  onSelected: () => setState(() => _tag = _tag == t ? null : t),
                ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),

          // 6. Time Range Filter
          Text(
            l10n.merchantReviewsFilterDate,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: l10n.merchantReviewsFilterDateAll,
                selected: _datePreset == _DatePreset.all && _customRange == null,
                onSelected: () => setState(() {
                  _datePreset = _DatePreset.all;
                  _customRange = null;
                }),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterDateToday,
                selected:
                    _datePreset == _DatePreset.today && _customRange == null,
                onSelected: () => setState(() {
                  _datePreset = _DatePreset.today;
                  _customRange = null;
                }),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterDate7Days,
                selected:
                    _datePreset == _DatePreset.past7Days && _customRange == null,
                onSelected: () => setState(() {
                  _datePreset = _DatePreset.past7Days;
                  _customRange = null;
                }),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterDate30Days,
                selected: _datePreset == _DatePreset.past30Days &&
                    _customRange == null,
                onSelected: () => setState(() {
                  _datePreset = _DatePreset.past30Days;
                  _customRange = null;
                }),
              ),
              if (_customRange != null)
                AccountFilterChip(
                  label:
                      '${_customRange!.start.day}/${_customRange!.start.month} - ${_customRange!.end.day}/${_customRange!.end.month}',
                  selected: true,
                  onSelected: () => setState(() => _customRange = null),
                ),
              ActionChip(
                avatar: const Icon(
                  DealGoIcons.calendar,
                  size: 16,
                  color: DealGoColors.primary,
                ),
                label: Text(l10n.merchantReviewsFilterDateCustom),
                onPressed: _pickCustomRange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                  side: BorderSide(color: DealGoColors.border),
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),

          // 7. Sort Order
          Text(
            l10n.merchantReviewsFilterSort,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: l10n.merchantReviewsFilterSortNewest,
                selected: _sort == MerchantReviewSort.newest,
                onSelected: () => setState(
                  () => _sort = MerchantReviewSort.newest,
                ),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterSortOldest,
                selected: _sort == MerchantReviewSort.oldest,
                onSelected: () => setState(
                  () => _sort = MerchantReviewSort.oldest,
                ),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterSortLowest,
                selected: _sort == MerchantReviewSort.lowestStars,
                onSelected: () => setState(
                  () => _sort = MerchantReviewSort.lowestStars,
                ),
              ),
              AccountFilterChip(
                label: l10n.merchantReviewsFilterSortHighest,
                selected: _sort == MerchantReviewSort.highestStars,
                onSelected: () => setState(
                  () => _sort = MerchantReviewSort.highestStars,
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: DealGoSecondaryButton(
                  key: const Key('merchant-reviews-filter-reset'),
                  label: l10n.merchantReviewsFilterReset,
                  onPressed: () {
                    widget.onReset();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: DealGoPrimaryButton(
                  key: const Key('merchant-reviews-filter-apply'),
                  label: l10n.merchantReviewsFilterApply,
                  onPressed: () {
                    widget.onApply(
                      stars: _stars,
                      replied: _replied,
                      hasComment: _hasComment,
                      visibility: _visibility,
                      tag: _tag,
                      datePreset: _datePreset,
                      customRange: _customRange,
                      sort: _sort,
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
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
              hint: 'VD: Cảm ơn bạn đã phản hồi, quán sẽ cải thiện món ăn...',
              showLabel: false,
              controller: _text,
              fieldKey: const Key('merchant-review-reply-text'),
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.done,
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
