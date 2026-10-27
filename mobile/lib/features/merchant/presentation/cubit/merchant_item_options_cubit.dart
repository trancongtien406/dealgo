import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/ui_message.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/replace_merchant_item_options.dart';

sealed class MerchantItemOptionsState {
  const MerchantItemOptionsState();
}

final class MerchantItemOptionsLoading extends MerchantItemOptionsState {
  const MerchantItemOptionsLoading();
}

final class MerchantItemOptionsFailed extends MerchantItemOptionsState {
  const MerchantItemOptionsFailed(this.message);

  final UiMessage message;
}

/// Draft of one dish's option layout. New groups/choices carry id '' until the
/// server assigns one; existing ids are sent back so they stay stable.
final class MerchantItemOptionsReady extends MerchantItemOptionsState {
  const MerchantItemOptionsReady({
    required this.item,
    required this.groups,
    this.saving = false,
    this.dirty = false,
    this.error,
    this.savedTick = 0,
  });

  final FoodMenuItem item;
  final List<FoodOptionGroup> groups;
  final bool saving;
  final bool dirty;
  final UiMessage? error;

  /// Bumps on every successful save so the page can confirm once.
  final int savedTick;

  MerchantItemOptionsReady copyWith({
    FoodMenuItem? item,
    List<FoodOptionGroup>? groups,
    bool? saving,
    bool? dirty,
    UiMessage? error,
    bool clearError = false,
    int? savedTick,
  }) {
    return MerchantItemOptionsReady(
      item: item ?? this.item,
      groups: groups ?? this.groups,
      saving: saving ?? this.saving,
      dirty: dirty ?? this.dirty,
      error: clearError ? null : (error ?? this.error),
      savedTick: savedTick ?? this.savedTick,
    );
  }
}

/// Same bounds the server enforces (FOOD_OPTIONS_INVALID); checked before sending.
const merchantOptionMaxGroups = 10;
const merchantOptionMaxChoices = 20;
const merchantOptionMaxDeltaVnd = 1000000;

bool merchantOptionGroupValid(FoodOptionGroup group) {
  final count = group.choices.length;
  final available = group.choices.where((c) => c.available).length;
  final names = group.choices.map((c) => c.label.trim().toLowerCase()).toSet();
  return group.title.trim().isNotEmpty &&
      count >= 1 &&
      count <= merchantOptionMaxChoices &&
      names.length == count &&
      !names.contains('') &&
      group.minSelect >= 0 &&
      group.maxSelect >= 1 &&
      group.minSelect <= group.maxSelect &&
      group.maxSelect <= count &&
      available >= group.minSelect &&
      group.choices.every(
        (c) =>
            c.extraVnd >= 0 &&
            c.extraVnd <= merchantOptionMaxDeltaVnd &&
            c.maxQuantity >= 1 &&
            c.maxQuantity <= 99,
      );
}

class MerchantItemOptionsCubit extends Cubit<MerchantItemOptionsState> {
  MerchantItemOptionsCubit({
    required this._getMerchantCatalog,
    required this._replaceOptions,
    required this.itemId,
  }) : super(const MerchantItemOptionsLoading());

  final GetMerchantCatalog _getMerchantCatalog;
  final ReplaceMerchantItemOptions _replaceOptions;
  final String itemId;

  Future<void> load(String? accessToken) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        MerchantItemOptionsFailed(
          UiMessage((l10n) => l10n.errorSessionExpired),
        ),
      );
      return;
    }
    emit(const MerchantItemOptionsLoading());
    try {
      final store = await _getMerchantCatalog(token);
      final matches = store.items.where((item) => item.id == itemId);
      if (isClosed) return;
      if (matches.isEmpty) {
        emit(
          MerchantItemOptionsFailed(
            UiMessage((l10n) => l10n.merchantOptionsItemMissing),
          ),
        );
        return;
      }
      final item = matches.first;
      emit(MerchantItemOptionsReady(item: item, groups: item.optionGroups));
    } catch (error) {
      if (!isClosed) emit(MerchantItemOptionsFailed(UiMessage.error(error)));
    }
  }

  void _edit(List<FoodOptionGroup> Function(List<FoodOptionGroup>) change) {
    final ready = state;
    if (ready is! MerchantItemOptionsReady || ready.saving) return;
    emit(
      ready.copyWith(
        groups: List.unmodifiable(change([...ready.groups])),
        dirty: true,
        clearError: true,
      ),
    );
  }

  /// Insert (index == null) or replace a group's name and bounds.
  void putGroup({
    int? index,
    required String title,
    required int minSelect,
    required int maxSelect,
  }) {
    _edit((groups) {
      if (index == null) {
        if (groups.length >= merchantOptionMaxGroups) return groups;
        groups.add(
          FoodOptionGroup(
            id: '',
            title: title.trim(),
            minSelect: minSelect,
            maxSelect: maxSelect,
            choices: const [],
          ),
        );
      } else {
        final group = groups[index];
        groups[index] = FoodOptionGroup(
          id: group.id,
          title: title.trim(),
          minSelect: minSelect,
          maxSelect: maxSelect,
          choices: group.choices,
        );
      }
      return groups;
    });
  }

  void removeGroup(int index) => _edit((groups) => groups..removeAt(index));

  /// Insert (choiceIndex == null) or replace a choice in group [groupIndex].
  void putChoice({
    required int groupIndex,
    int? choiceIndex,
    required String label,
    required int extraVnd,
    required bool available,
    int maxQuantity = 1,
  }) {
    _edit((groups) {
      final group = groups[groupIndex];
      final choices = [...group.choices];
      final mq = maxQuantity < 1 ? 1 : maxQuantity;
      if (choiceIndex == null) {
        if (choices.length >= merchantOptionMaxChoices) return groups;
        choices.add(
          FoodOptionChoice(
            id: '',
            label: label.trim(),
            extraVnd: extraVnd,
            available: available,
            maxQuantity: mq,
          ),
        );
      } else {
        choices[choiceIndex] = FoodOptionChoice(
          id: choices[choiceIndex].id,
          label: label.trim(),
          extraVnd: extraVnd,
          available: available,
          maxQuantity: mq,
        );
      }
      groups[groupIndex] = _withChoices(group, choices);
      return groups;
    });
  }

  void removeChoice(int groupIndex, int choiceIndex) {
    _edit((groups) {
      final group = groups[groupIndex];
      groups[groupIndex] = _withChoices(
        group,
        [...group.choices]..removeAt(choiceIndex),
      );
      return groups;
    });
  }

  Future<void> save(String? accessToken) async {
    final ready = state;
    if (ready is! MerchantItemOptionsReady || ready.saving) return;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        ready.copyWith(error: UiMessage((l10n) => l10n.errorSessionExpired)),
      );
      return;
    }
    final names = ready.groups.map((g) => g.title.trim().toLowerCase()).toSet();
    if (names.length != ready.groups.length ||
        !ready.groups.every(merchantOptionGroupValid)) {
      emit(
        ready.copyWith(
          error: UiMessage((l10n) => l10n.merchantOptionsInvalidGroup),
        ),
      );
      return;
    }
    emit(ready.copyWith(saving: true, clearError: true));
    try {
      final saved = await _replaceOptions(
        accessToken: token,
        itemId: itemId,
        groups: ready.groups,
      );
      if (isClosed) return;
      emit(
        MerchantItemOptionsReady(
          item: saved,
          groups: saved.optionGroups,
          savedTick: ready.savedTick + 1,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      final current = state;
      if (current is MerchantItemOptionsReady) {
        emit(current.copyWith(saving: false, error: UiMessage.error(error)));
      }
    }
  }
}

FoodOptionGroup _withChoices(
  FoodOptionGroup group,
  List<FoodOptionChoice> choices,
) {
  // Keep bounds satisfiable while the merchant edits (max never above count).
  final maxSelect = group.maxSelect > choices.length && choices.isNotEmpty
      ? (group.maxSelect.clamp(1, choices.length))
      : group.maxSelect;
  return FoodOptionGroup(
    id: group.id,
    title: group.title,
    minSelect: group.minSelect.clamp(0, maxSelect),
    maxSelect: maxSelect,
    choices: List.unmodifiable(choices),
  );
}
