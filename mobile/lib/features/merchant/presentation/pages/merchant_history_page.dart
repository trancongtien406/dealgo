import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_profile_avatar.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../shell/presentation/account_widgets.dart';
import '../../domain/entities/merchant_menu_models.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';

enum _DatePreset { all, today, past7Days, past30Days }

/// M020 — finished order history (DEC-PROD-039).
class MerchantHistoryPageView extends StatefulWidget {
  const MerchantHistoryPageView({super.key});

  @override
  State<MerchantHistoryPageView> createState() =>
      _MerchantHistoryPageViewState();
}

class _MerchantHistoryPageViewState extends State<MerchantHistoryPageView> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _tab; // null = ALL, DELIVERED, CANCELLED
  _DatePreset _datePreset = _DatePreset.all;
  DateTimeRange? _customRange;
  var _hasSearchText = false;
  var _loading = true;
  var _loadingMore = false;
  var _loadMoreFailed = false;
  var _generation = 0;
  Object? _failure;
  MerchantHistoryPage? _page;

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
    final page = _page;
    if (page == null || _loadingMore || _loadMoreFailed) return;
    if (page.items.length >= page.total) return;
    unawaited(_loadMore());
  }

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

  String _dateFilterLabel() {
    if (_customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return '${s.day}/${s.month} - ${e.day}/${e.month}';
    }
    return switch (_datePreset) {
      _DatePreset.all => 'Toàn bộ thời gian',
      _DatePreset.today => 'Hôm nay',
      _DatePreset.past7Days => '7 ngày qua',
      _DatePreset.past30Days => '30 ngày qua',
    };
  }

  bool get _hasActiveFilters =>
      _tab != null || _datePreset != _DatePreset.all || _customRange != null;

  void _resetFilters() {
    _search.clear();
    setState(() {
      _tab = null;
      _datePreset = _DatePreset.all;
      _customRange = null;
    });
    _load();
  }

  void _openFilterAndStatsSheet() {
    showDealGoSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _HistoryFilterBottomSheet(
        currentTab: _tab,
        currentDatePreset: _datePreset,
        currentCustomRange: _customRange,
        page: _page,
        onApply: (selectedTab, selectedPreset, selectedRange) {
          setState(() {
            _tab = selectedTab;
            _datePreset = selectedPreset;
            _customRange = selectedRange;
          });
          _load();
        },
        onReset: _resetFilters,
      ),
    );
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _loadMoreFailed = false;
      _failure = null;
    });
    final (from, to) = _computeDateRange();
    try {
      final page = await context
          .read<MerchantOrdersRepository>()
          .listOrderHistory(
            accessToken: (merchantAccessToken(context) ?? ''),
            page: 1,
            limit: _pageSize,
            tab: _tab,
            q: _search.text.trim().isEmpty ? null : _search.text.trim(),
            from: from,
            to: to,
          );
      if (mounted && generation == _generation) {
        setState(() {
          _page = page;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failure = error;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final current = _page;
    if (current == null || _loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    final (from, to) = _computeDateRange();
    try {
      final next = await context
          .read<MerchantOrdersRepository>()
          .listOrderHistory(
            accessToken: (merchantAccessToken(context) ?? ''),
            page: current.page + 1,
            limit: _pageSize,
            tab: _tab,
            q: _search.text.trim().isEmpty ? null : _search.text.trim(),
            from: from,
            to: to,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _page = MerchantHistoryPage(
          items: [...current.items, ...next.items],
          page: next.page,
          limit: next.limit,
          total: next.total,
          deliveredCount: next.deliveredCount,
          deliveredRevenueVnd: next.deliveredRevenueVnd,
        );
        _loadingMore = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final hasFilters = _hasSearchText || _hasActiveFilters;
    if (hasFilters) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s24),
        child: DealGoStateView(
          art: DealGoStateArt.noSearch,
          title: 'Không tìm thấy đơn hàng',
          message: 'Không có đơn nào khớp với bộ lọc hoặc từ khóa tìm kiếm.',
          actionLabel: 'Xóa bộ lọc',
          onAction: _resetFilters,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s24),
      child: DealGoStateView(
        art: DealGoStateArt.noOrders,
        title: l10n.merchantHistoryEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final page = _page;

    return MerchantPageFrame(
      title: l10n.merchantHistoryTitle,
      onBack: () => merchantBack(context),
      trailing: IconButton(
        key: const Key('merchant-history-filter-button'),
        icon: Badge(
          isLabelVisible: _hasActiveFilters,
          child: const Icon(DealGoIcons.filter),
        ),
        tooltip: 'Bộ lọc & Thống kê',
        onPressed: _openFilterAndStatsSheet,
      ),
      body: DealGoRefresh(
        onRefresh: _load,
        child: ListView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: dealGoScrollPadding(context, merchantPagePadding),
          children: [
            // 1. Search Bar
            DealGoTextField(
              label: l10n.merchantHistorySearch,
              showLabel: false,
              hint: 'Tìm theo mã đơn (#...), tên khách, món ăn...',
              controller: _search,
              fieldKey: const Key('merchant-history-search'),
              textInputAction: TextInputAction.search,
              prefixIcon: DealGoIcons.search,
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasSearchText)
                    IconButton(
                      key: const Key('merchant-history-search-clear'),
                      icon: const Icon(DealGoIcons.close, size: 18),
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                    ),
                  IconButton(
                    key: const Key('merchant-history-search-go'),
                    icon: const Icon(DealGoIcons.search),
                    tooltip: 'Tìm kiếm',
                    onPressed: _load,
                  ),
                ],
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: DealGoSpacing.s8),

            // 2. Status Filter Tabs & Filter Sheet Trigger
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AccountFilterChip(
                    key: const Key('merchant-history-tab-all'),
                    label: l10n.merchantHistoryAll,
                    selected: _tab == null,
                    onSelected: () {
                      if (_tab == null) return;
                      setState(() => _tab = null);
                      _load();
                    },
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  AccountFilterChip(
                    key: const Key('merchant-history-tab-done'),
                    label: l10n.merchantHistoryDone,
                    selected: _tab == 'DELIVERED',
                    onSelected: () {
                      if (_tab == 'DELIVERED') return;
                      setState(() => _tab = 'DELIVERED');
                      _load();
                    },
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  AccountFilterChip(
                    key: const Key('merchant-history-tab-cancelled'),
                    label: l10n.merchantHistoryCancelled,
                    selected: _tab == 'CANCELLED',
                    onSelected: () {
                      if (_tab == 'CANCELLED') return;
                      setState(() => _tab = 'CANCELLED');
                      _load();
                    },
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  ActionChip(
                    key: const Key('merchant-history-open-filter-sheet'),
                    avatar: Icon(
                      DealGoIcons.filter,
                      size: 14,
                      color: _hasActiveFilters
                          ? DealGoColors.primary
                          : DealGoColors.textSecondary,
                    ),
                    label: Text(
                      _hasActiveFilters
                          ? 'Đã lọc (${_dateFilterLabel()})'
                          : 'Bộ lọc & Thống kê',
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
                    onPressed: _openFilterAndStatsSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s8),

            // 3. Compact Stats Strip (only 36px high, doesn't eat screen space)
            if (page != null) ...[
              _CompactSummaryStrip(
                page: page,
                dateLabel: _dateFilterLabel(),
                onTap: _openFilterAndStatsSheet,
              ),
              const SizedBox(height: DealGoSpacing.s12),
            ],

            // 4. State Handling & Order List (The Main Content)
            if (_loading && page == null)
              const DealGoSkeletonList(itemCount: 4, padding: EdgeInsets.zero)
            else if (_failure != null && page == null)
              DealGoStateView.failure(
                context,
                onRetry: _load,
                cause: _failure,
                message: _failure is ApiException
                    ? apiErrorText(l10n, _failure as ApiException)
                    : null,
              )
            else if (page == null || page.items.isEmpty)
              _buildEmptyState(context, l10n)
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.merchantHistoryList} (${page.total})',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_hasSearchText || _hasActiveFilters)
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(DealGoIcons.close, size: 14),
                      label: const Text('Đặt lại bộ lọc'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: DealGoColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s8),
              for (final row in page.items) ...[
                _HistoryOrderCard(
                  row: row,
                  onTap: () =>
                      context.push(MerchantRoutes.order(row.id), extra: row),
                ),
                const SizedBox(height: DealGoSpacing.s8),
              ],

              // Pagination & Footer
              if (_loadingMore)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: DealGoSpacing.s8),
                        Text('Đang tải thêm đơn...'),
                      ],
                    ),
                  ),
                )
              else if (_loadMoreFailed)
                Center(
                  child: TextButton.icon(
                    key: const Key('merchant-history-more-retry'),
                    onPressed: _loadMore,
                    icon: const Icon(DealGoIcons.refresh, size: 16),
                    label: Text(l10n.actionRetry),
                  ),
                )
              else if (page.items.length >= page.total && page.total > 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DealGoSpacing.s16,
                    ),
                    child: Text(
                      '✓ Đã hiển thị tất cả ${page.total} đơn hàng',
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact single-line summary strip that preserves screen real-estate for the order list.
class _CompactSummaryStrip extends StatelessWidget {
  const _CompactSummaryStrip({
    required this.page,
    required this.dateLabel,
    required this.onTap,
  });

  final MerchantHistoryPage page;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DealGoRadius.small),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: DealGoColors.subtlePurple,
          borderRadius: BorderRadius.circular(DealGoRadius.small),
          border: Border.all(
            color: DealGoColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              DealGoIcons.receipt,
              size: 16,
              color: DealGoColors.primary,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text.rich(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.text,
                  ),
                  children: [
                    const TextSpan(text: 'Doanh thu món: '),
                    TextSpan(
                      text: formatVnd(page.deliveredRevenueVnd),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: DealGoColors.brandGreen,
                      ),
                    ),
                    TextSpan(text: ' (${page.deliveredCount} đơn)'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s6),
            Text(
              dateLabel,
              style: textTheme.bodySmall?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s4),
            const Icon(
              DealGoIcons.chevronRight,
              size: 14,
              color: DealGoColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed Filter & Statistics Modal Bottom Sheet.
class _HistoryFilterBottomSheet extends StatefulWidget {
  const _HistoryFilterBottomSheet({
    required this.currentTab,
    required this.currentDatePreset,
    required this.currentCustomRange,
    required this.page,
    required this.onApply,
    required this.onReset,
  });

  final String? currentTab;
  final _DatePreset currentDatePreset;
  final DateTimeRange? currentCustomRange;
  final MerchantHistoryPage? page;
  final void Function(
    String? tab,
    _DatePreset preset,
    DateTimeRange? customRange,
  ) onApply;
  final VoidCallback onReset;

  @override
  State<_HistoryFilterBottomSheet> createState() =>
      _HistoryFilterBottomSheetState();
}

class _HistoryFilterBottomSheetState extends State<_HistoryFilterBottomSheet> {
  late String? _tab = widget.currentTab;
  late _DatePreset _preset = widget.currentDatePreset;
  late DateTimeRange? _customRange = widget.currentCustomRange;

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
        _preset = _DatePreset.all;
        _customRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final page = widget.page;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: DealGoSpacing.s16,
        right: DealGoSpacing.s16,
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
                'Bộ lọc & Thống kê chi tiết',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(DealGoIcons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Đóng',
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),

          // 1. Full Dashboard Panel
          if (page != null) ...[
            Container(
              padding: const EdgeInsets.all(DealGoSpacing.s14),
              decoration: BoxDecoration(
                color: DealGoColors.card,
                borderRadius: BorderRadius.circular(DealGoRadius.card),
                border: Border.all(color: DealGoColors.border),
                boxShadow: DealGoShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: DealGoColors.subtlePurple,
                          borderRadius:
                              BorderRadius.circular(DealGoRadius.small),
                        ),
                        child: const Icon(
                          DealGoIcons.receipt,
                          color: DealGoColors.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s8),
                      Text(
                        'Tổng quan theo bộ lọc',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatVnd(page.deliveredRevenueVnd),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: DealGoColors.brandGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: DealGoSpacing.s2),
                            Text(
                              'Doanh thu món',
                              style: textTheme.bodySmall?.copyWith(
                                color: DealGoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: DealGoColors.border,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  DealGoIcons.check,
                                  size: 14,
                                  color: DealGoColors.brandGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${page.deliveredCount}',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DealGoSpacing.s2),
                            Text(
                              'Thành công',
                              style: textTheme.bodySmall?.copyWith(
                                color: DealGoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: DealGoColors.border,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${page.total}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s2),
                            Text(
                              'Toàn bộ đơn',
                              style: textTheme.bodySmall?.copyWith(
                                color: DealGoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s16),
          ],

          // 2. Status Filter
          Text(
            'Trạng thái đơn hàng',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: 'Tất cả trạng thái',
                selected: _tab == null,
                onSelected: () => setState(() => _tab = null),
              ),
              AccountFilterChip(
                label: 'Giao thành công',
                selected: _tab == 'DELIVERED',
                onSelected: () => setState(() => _tab = 'DELIVERED'),
              ),
              AccountFilterChip(
                label: 'Đã hủy',
                selected: _tab == 'CANCELLED',
                onSelected: () => setState(() => _tab = 'CANCELLED'),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),

          // 3. Time Filter
          Text(
            'Khoảng thời gian',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              AccountFilterChip(
                label: 'Toàn bộ',
                selected: _preset == _DatePreset.all && _customRange == null,
                onSelected: () => setState(() {
                  _preset = _DatePreset.all;
                  _customRange = null;
                }),
              ),
              AccountFilterChip(
                label: 'Hôm nay',
                selected: _preset == _DatePreset.today && _customRange == null,
                onSelected: () => setState(() {
                  _preset = _DatePreset.today;
                  _customRange = null;
                }),
              ),
              AccountFilterChip(
                label: '7 ngày qua',
                selected:
                    _preset == _DatePreset.past7Days && _customRange == null,
                onSelected: () => setState(() {
                  _preset = _DatePreset.past7Days;
                  _customRange = null;
                }),
              ),
              AccountFilterChip(
                label: '30 ngày qua',
                selected:
                    _preset == _DatePreset.past30Days && _customRange == null,
                onSelected: () => setState(() {
                  _preset = _DatePreset.past30Days;
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
                label: const Text('Chọn dải ngày'),
                onPressed: _pickCustomRange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                  side: BorderSide(color: DealGoColors.border),
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: DealGoSecondaryButton(
                  label: 'Đặt lại',
                  onPressed: () {
                    widget.onReset();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: DealGoPrimaryButton(
                  label: 'Áp dụng',
                  onPressed: () {
                    widget.onApply(_tab, _preset, _customRange);
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

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({
    required this.row,
    required this.onTap,
  });

  final MerchantHistoryOrder row;
  final VoidCallback onTap;

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)} · ${two(local.day)}/${two(local.month)}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final chip = switch (row.status) {
      'DELIVERED' => const DealGoChip(
          label: 'Hoàn thành',
          tone: DealGoChipTone.success,
          leading:
              Icon(DealGoIcons.check, size: 12, color: DealGoColors.brandGreen),
        ),
      'CANCELLED' => const DealGoChip(
          label: 'Đã hủy',
          tone: DealGoChipTone.danger,
          leading:
              Icon(DealGoIcons.close, size: 12, color: DealGoColors.danger),
        ),
      'FAILED' => const DealGoChip(
          label: 'Thất bại',
          tone: DealGoChipTone.danger,
        ),
      _ => DealGoChip(
          label: row.status,
          tone: DealGoChipTone.neutral,
        ),
    };

    return MerchantPanel(
      key: Key('merchant-history-${row.id}'),
      padding: EdgeInsets.zero,
      child: InkWell(
        key: Key('merchant-history-order-${row.id}'),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Order ID + Completed Time + Status Chip
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s8,
                      vertical: DealGoSpacing.s2,
                    ),
                    decoration: BoxDecoration(
                      color: DealGoColors.subtlePurple,
                      borderRadius: BorderRadius.circular(DealGoRadius.small),
                    ),
                    child: Text(
                      '#${shortRef(row.id)}',
                      style: textTheme.titleSmall?.copyWith(
                        color: DealGoColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      _formatDateTime(row.finishedAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  chip,
                ],
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Divider(height: 1, thickness: 1, color: DealGoColors.border),
              const SizedBox(height: DealGoSpacing.s8),

              // Customer & Money Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DealGoProfileAvatar(
                    avatarUrl: resolveMediaUrl(row.customerAvatarUrl),
                    size: 38,
                    semanticLabel: row.customerName,
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.customerName?.isNotEmpty == true
                              ? row.customerName!
                              : 'Khách hàng',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DealGoSpacing.s2),
                        Text(
                          'Tiền món: ${formatVnd(row.subtotalVnd)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatVnd(row.totalVnd),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: DealGoColors.primary,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s2),
                      Text(
                        'Tổng đơn (COD)',
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Dishes Row
              if (row.lineSummary.isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                    vertical: DealGoSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    color: DealGoColors.amberSurface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DealGoRadius.small),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        DealGoIcons.food,
                        size: 16,
                        color: DealGoColors.amber,
                      ),
                      const SizedBox(width: DealGoSpacing.s8),
                      Expanded(
                        child: Text(
                          row.lineSummary,
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.text,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: DealGoSpacing.s8),
              Divider(
                height: 1,
                thickness: 1,
                color: DealGoColors.border.withValues(alpha: 0.5),
              ),
              const SizedBox(height: DealGoSpacing.s8),

              // Footer: Action Hint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Xem chi tiết đơn hàng',
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    DealGoIcons.chevronRight,
                    size: 16,
                    color: DealGoColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
