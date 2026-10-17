import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'account_routes.dart';
import 'account_widgets.dart';
import 'address_draft_cubit.dart';

enum _PlaceFilter { all, nearby, saved }

enum _SampleGroup { recent, suggested }

class _PlaceSample {
  const _PlaceSample({
    required this.title,
    required this.detail,
    required this.group,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String title;
  final String detail;
  final _SampleGroup group;
  final IconData icon;
  final Color background;
  final Color foreground;
}

const _samples = <_PlaceSample>[
  _PlaceSample(
    title: 'Sân bay Quốc tế Đà Nẵng',
    detail: 'Mẫu · Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
    group: _SampleGroup.recent,
    icon: Icons.place_outlined,
    background: DealGoColors.subtlePurple,
    foreground: DealGoColors.primary,
  ),
  _PlaceSample(
    title: 'Cầu Rồng',
    detail: 'Mẫu · Nguyễn Văn Linh, Đà Nẵng',
    group: _SampleGroup.recent,
    icon: Icons.place_outlined,
    background: DealGoColors.subtlePurple,
    foreground: DealGoColors.primary,
  ),
  _PlaceSample(
    title: 'Biển Mỹ Khê',
    detail: 'Mẫu · Võ Nguyên Giáp, Sơn Trà, Đà Nẵng',
    group: _SampleGroup.recent,
    icon: Icons.place_outlined,
    background: DealGoColors.greenSurface,
    foreground: DealGoColors.brandGreen,
  ),
  _PlaceSample(
    title: 'Vincom Plaza Đà Nẵng',
    detail: 'Mẫu · 910A Ngô Quyền, Sơn Trà',
    group: _SampleGroup.suggested,
    icon: Icons.place_outlined,
    background: DealGoColors.greenSurface,
    foreground: DealGoColors.brandGreen,
  ),
  _PlaceSample(
    title: 'Bệnh viện Đà Nẵng',
    detail: 'Mẫu · Hải Châu, Đà Nẵng',
    group: _SampleGroup.suggested,
    icon: Icons.place_outlined,
    background: DealGoColors.dangerSurface,
    foreground: DealGoColors.danger,
  ),
];

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({required this.shellPath, super.key});

  final String shellPath;

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final TextEditingController _query = TextEditingController();
  var _filter = _PlaceFilter.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String title, String detail) {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(query) ||
        detail.toLowerCase().contains(query);
  }

  void _clearQuery() {
    _query.clear();
    setState(() {});
  }

  void _leaveWithoutPin() {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<AddressDraftCubit>().state;
    final query = _query.text.trim();
    final recent = [
      for (final place in _samples)
        if (place.group == _SampleGroup.recent &&
            _filter != _PlaceFilter.saved &&
            _matches(place.title, place.detail))
          place,
    ];
    final suggested = [
      for (final place in _samples)
        if (place.group == _SampleGroup.suggested &&
            _filter != _PlaceFilter.saved &&
            _matches(place.title, place.detail))
          place,
    ];
    final saved = [
      for (final label in labels)
        if (_filter != _PlaceFilter.nearby &&
            _matches(label, 'Nhãn trên máy trong phiên này'))
          label,
    ];
    final showSavedSection = _filter != _PlaceFilter.nearby;
    final hasMatches =
        recent.isNotEmpty || suggested.isNotEmpty || saved.isNotEmpty;
    final showEmpty = query.isNotEmpty && !hasMatches;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountScreenHeader(
              title: showEmpty ? 'Tìm địa điểm' : 'Tìm kiếm địa điểm',
              subtitle: showEmpty ? 'DealGo · Biến thể trạng thái' : null,
            ),
            if (!showEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                  DealGoDimensions.pageGutter,
                  0,
                ),
                child: TextField(
                  key: const Key('place-search-field'),
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: accountFieldDecoration(
                    context,
                    hint: 'Địa chỉ, địa điểm hoặc tên tòa nhà...',
                    prefix: const Icon(
                      Icons.search,
                      color: DealGoColors.textSecondary,
                    ),
                    suffix: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa từ khóa',
                            onPressed: _clearQuery,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
            if (!showEmpty) ...[
              const SizedBox(height: DealGoSpacing.s12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoDimensions.pageGutter,
                ),
                child: _PlaceFilters(
                  selected: _filter,
                  onSelected: (filter) => setState(() => _filter = filter),
                ),
              ),
            ],
            Expanded(
              child: showEmpty
                  ? _EmptySearch(query: query)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s16,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s16,
                      ),
                      children: [
                        Text(
                          'Địa điểm dưới đây là mẫu trên máy, không phải kết quả từ máy chủ.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: DealGoSpacing.s16),
                        if (recent.isNotEmpty) ...[
                          const AccountSectionHeader(
                            title: 'Địa điểm gần đây',
                            action: AccountLinkText('Xóa lịch sử'),
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          for (final place in recent) ...[
                            _PlaceRow(
                              title: place.title,
                              detail: place.detail,
                              icon: place.icon,
                              background: place.background,
                              foreground: place.foreground,
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                          ],
                        ],
                        if (showSavedSection) ...[
                          AccountSectionHeader(
                            title: 'Địa chỉ đã lưu',
                            action: TextButton(
                              onPressed: () => context.push(
                                AccountRoutes.addresses(widget.shellPath),
                              ),
                              child: const AccountLinkText('Xem tất cả'),
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          if (saved.isEmpty)
                            Text(
                              'Chưa có nhãn trên máy.',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            for (final label in saved) ...[
                              _PlaceRow(
                                title: label,
                                detail: 'Nhãn trên máy trong phiên này',
                                icon: Icons.home_outlined,
                                background: DealGoColors.subtlePurple,
                                foreground: DealGoColors.primary,
                              ),
                              const SizedBox(height: DealGoSpacing.s12),
                            ],
                          const SizedBox(height: DealGoSpacing.s8),
                        ],
                        if (suggested.isNotEmpty) ...[
                          const AccountSectionHeader(title: 'Gợi ý cho bạn'),
                          const SizedBox(height: DealGoSpacing.s12),
                          for (final place in suggested) ...[
                            _PlaceRow(
                              title: place.title,
                              detail: place.detail,
                              icon: place.icon,
                              background: place.background,
                              foreground: place.foreground,
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                          ],
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: showEmpty
                  ? Row(
                      children: [
                        Expanded(
                          child: DealGoSecondaryButton(
                            label: 'Tìm lại',
                            onPressed: _clearQuery,
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: DealGoPrimaryButton(
                            label: 'Chọn trên bản đồ',
                            onPressed: _leaveWithoutPin,
                          ),
                        ),
                      ],
                    )
                  : DealGoPrimaryButton(
                      label: 'Chọn vị trí trên bản đồ',
                      trailingIcon: Icons.place_outlined,
                      onPressed: _leaveWithoutPin,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceFilters extends StatelessWidget {
  const _PlaceFilters({required this.selected, required this.onSelected});

  final _PlaceFilter selected;
  final ValueChanged<_PlaceFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoSegmentedControl(
      value: selected.name,
      onChanged: (id) => onSelected(
        _PlaceFilter.values.firstWhere((e) => e.name == id),
      ),
      items: [
        DealGoSegmentItem(id: 'all', label: l10n.filterAll),
        DealGoSegmentItem(id: 'nearby', label: l10n.filterNearby),
        DealGoSegmentItem(id: 'saved', label: l10n.filterSaved),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.title,
    required this.detail,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Row(
        children: [
          AccountToneIcon(
            icon: icon,
            background: background,
            foreground: foreground,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(detail, style: textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: DealGoColors.textSecondary),
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
      ),
      children: [
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFE8F1FF),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(Icons.search, color: Color(0xFF3B82F6), size: 32),
            ),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          'Không tìm thấy địa điểm',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          'Không có kết quả phù hợp với từ khóa vừa nhập. Bạn có thể sửa từ khóa hoặc tự ghim trên bản đồ.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s20),
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Từ khóa tìm kiếm',
                style: textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: DealGoSpacing.s8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.canvas,
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(DealGoSpacing.s12),
                  child: Text(query, style: textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gợi ý',
                style: textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              const _HintLine(
                icon: Icons.edit_outlined,
                label: 'Kiểm tra chính tả địa chỉ',
              ),
              const Divider(height: DealGoSpacing.s20),
              const _HintLine(
                icon: Icons.place_outlined,
                label: 'Chọn vị trí trực tiếp trên bản đồ',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DealGoColors.textSecondary),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(child: Text(label)),
      ],
    );
  }
}
