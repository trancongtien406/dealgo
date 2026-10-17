import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import 'account_routes.dart';
import 'account_widgets.dart';
import 'address_draft_cubit.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({required this.shellPath, super.key});

  final String shellPath;

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  final TextEditingController _label = TextEditingController();
  int? _editingIndex;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _commit() {
    final cubit = context.read<AddressDraftCubit>();
    final editing = _editingIndex;
    final wrote = editing == null
        ? cubit.addLabel(_label.text)
        : cubit.replaceLabel(editing, _label.text);
    if (!wrote) {
      return;
    }
    _label.clear();
    setState(() => _editingIndex = null);
  }

  void _beginEdit(int index, String value) {
    _label.text = value;
    setState(() => _editingIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<AddressDraftCubit>().state;
    final editing = _editingIndex;
    final canAdd = labels.length < AddressDraftCubit.limit || editing != null;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccountScreenHeader(title: 'Địa chỉ đã lưu'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  Text('Địa chỉ của tôi', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    'Lưu những địa điểm thường sử dụng để đặt xe và nhận hàng nhanh hơn.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    'Nhãn bạn gõ chỉ nằm trên máy trong phiên này.',
                    style: textTheme.bodySmall,
                  ),
                  if (canAdd) ...[
                    const SizedBox(height: DealGoSpacing.s12),
                    TextField(
                      key: const Key('address-label-field'),
                      controller: _label,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _commit(),
                      decoration: accountFieldDecoration(
                        context,
                        hint: 'Nhập nhãn trên máy',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('address-label-add'),
                        onPressed: _commit,
                        child: Text(
                          editing == null
                              ? 'Ghi nhãn trên máy'
                              : 'Ghi lại nhãn trên máy',
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: DealGoSpacing.s12),
                    Text(
                      'Phiên này chỉ giữ hai nhãn trên máy.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: DealGoSpacing.s8),
                  if (labels.isEmpty)
                    Text(
                      'Chưa có nhãn trên máy trong phiên này.',
                      style: textTheme.bodyMedium,
                    )
                  else
                    for (var index = 0; index < labels.length; index++) ...[
                      _LabelCard(
                        index: index,
                        label: labels[index],
                        onEdit: () => _beginEdit(index, labels[index]),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                  const SizedBox(height: DealGoSpacing.s8),
                  Text('Bản đồ địa chỉ', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  _DraftMap(caption: labels.isEmpty ? null : labels.first),
                  const SizedBox(height: DealGoSpacing.s12),
                  const _SearchHint(),
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
              child: DealGoPrimaryButton(
                label: 'Thêm địa chỉ mới',
                trailingIcon: Icons.arrow_forward,
                onPressed: () =>
                    context.push(AccountRoutes.places(widget.shellPath)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({
    required this.index,
    required this.label,
    required this.onEdit,
  });

  final int index;
  final String label;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDefault = index == 0;
    return DealGoCard(
      key: Key('saved-label-$index'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AccountToneIcon(
                icon: isDefault ? Icons.home_outlined : Icons.work_outline,
                background: isDefault
                    ? DealGoColors.subtlePurple
                    : const Color(0xFFE8F1FF),
                foreground: isDefault
                    ? DealGoColors.primary
                    : const Color(0xFF2563EB),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nhãn trên máy trong phiên này',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isDefault)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.greenSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s8,
                      vertical: DealGoSpacing.s4,
                    ),
                    child: Text(
                      'Mặc định',
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.brandGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: DealGoSpacing.s24),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onEdit,
              child: Text(isDefault ? 'Chỉnh sửa' : 'Sửa'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftMap extends StatelessWidget {
  const _DraftMap({required this.caption});

  final String? caption;

  @override
  Widget build(BuildContext context) {
    final label = caption;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: ColoredBox(
        color: const Color(0xFFE7F2EA),
        child: SizedBox(
          height: 168,
          child: Stack(
            children: [
              const Positioned(
                left: 72,
                top: -20,
                bottom: -20,
                child: _MapRoad(),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.card,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(DealGoSpacing.s8),
                        child: Icon(
                          Icons.place,
                          color: DealGoColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.card,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s12,
                          vertical: DealGoSpacing.s4,
                        ),
                        child: Text(
                          label ?? 'Minh họa trên máy',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: DealGoColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapRoad extends StatelessWidget {
  const _MapRoad();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.5,
      child: const ColoredBox(
        color: Color(0xFFD5E6F5),
        child: SizedBox(width: 42, height: 240),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              color: DealGoColors.primary,
              size: 20,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                'Bạn có thể tìm kiếm hoặc ghim địa chỉ chính xác trên bản đồ khi thêm mới.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: DealGoColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
