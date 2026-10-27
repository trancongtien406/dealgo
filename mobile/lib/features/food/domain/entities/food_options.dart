/// DEC-PROD-033 — dish option groups (size, topping…) from the store catalog.
/// The server re-validates and prices every choice at placement; the app only
/// mirrors the rules so the customer sees the right total and cannot submit an
/// obviously invalid choice.
class FoodOptionChoice {
  const FoodOptionChoice({
    required this.id,
    required this.label,
    this.extraVnd = 0,
    this.available = true,
    this.maxQuantity = 1,
  });

  final String id;
  final String label;

  /// Per-unit surcharge (server `priceDeltaVnd`).
  final int extraVnd;
  final bool available;

  /// DEC-PROD-042 — max times this choice may be selected on one line.
  final int maxQuantity;
}

class FoodOptionGroup {
  const FoodOptionGroup({
    required this.id,
    required this.title,
    required this.minSelect,
    required this.maxSelect,
    required this.choices,
  });

  final String id;
  final String title;
  final int minSelect;
  final int maxSelect;
  final List<FoodOptionChoice> choices;

  bool get required => minSelect > 0;
  bool get multi => maxSelect > 1;
}

/// What an order line kept of a chosen option (receipt / kitchen ticket).
class FoodLineOption {
  const FoodLineOption({
    required this.groupName,
    required this.name,
    required this.priceDeltaVnd,
    this.quantity = 1,
    this.optionId,
  });

  /// Catalog option id at placement (lets "Đặt lại" rebuild the choice).
  final String? optionId;
  final String groupName;
  final String name;
  final int priceDeltaVnd;
  final int quantity;
}

/// Immutable selection state for one dish; the options page renders it.
class FoodOptionSelection {
  FoodOptionSelection._(this.groups, this._qty);

  /// Pre-picks the first available choice of single-choice required groups.
  factory FoodOptionSelection.initial(List<FoodOptionGroup> groups) {
    final qty = <String, Map<String, int>>{
      for (final group in groups) group.id: {},
    };
    for (final group in groups) {
      if (group.required && !group.multi) {
        for (final choice in group.choices) {
          if (choice.available) {
            qty[group.id]![choice.id] = 1;
            break;
          }
        }
      }
    }
    return FoodOptionSelection._(groups, qty);
  }

  final List<FoodOptionGroup> groups;

  /// groupId → optionId → quantity
  final Map<String, Map<String, int>> _qty;

  Set<String> picked(String groupId) =>
      (_qty[groupId] ?? const <String, int>{}).keys.toSet();

  int quantityOf(String groupId, String optionId) =>
      _qty[groupId]?[optionId] ?? 0;

  int _groupTotal(String groupId) {
    var total = 0;
    for (final q in (_qty[groupId] ?? const <String, int>{}).values) {
      total += q;
    }
    return total;
  }

  /// Single-choice swap; multi toggle; maxQuantity>1 uses ±1 steppers via [setQuantity].
  FoodOptionSelection toggle(FoodOptionGroup group, FoodOptionChoice choice) {
    if (!choice.available) return this;
    if (choice.maxQuantity > 1) {
      final current = quantityOf(group.id, choice.id);
      return setQuantity(group, choice, current > 0 ? 0 : 1);
    }
    final next = {...(_qty[group.id] ?? <String, int>{})};
    if (group.multi) {
      if (next.containsKey(choice.id)) {
        next.remove(choice.id);
      } else if (_groupTotal(group.id) < group.maxSelect) {
        next[choice.id] = 1;
      } else {
        return this;
      }
    } else if (next.containsKey(choice.id) && !group.required) {
      next.clear();
    } else {
      next
        ..clear()
        ..[choice.id] = 1;
    }
    return FoodOptionSelection._(groups, {..._qty, group.id: next});
  }

  FoodOptionSelection setQuantity(
    FoodOptionGroup group,
    FoodOptionChoice choice,
    int quantity,
  ) {
    if (!choice.available) return this;
    final q = quantity.clamp(0, choice.maxQuantity);
    final next = {...(_qty[group.id] ?? <String, int>{})};
    final others = _groupTotal(group.id) - (next[choice.id] ?? 0);
    if (others + q > group.maxSelect) return this;
    if (q <= 0) {
      next.remove(choice.id);
    } else {
      next[choice.id] = q;
    }
    return FoodOptionSelection._(groups, {..._qty, group.id: next});
  }

  bool get isComplete => groups.every((group) {
    final count = _groupTotal(group.id);
    return count >= group.minSelect && count <= group.maxSelect;
  });

  int get extrasVnd {
    var total = 0;
    for (final group in groups) {
      for (final choice in group.choices) {
        total += choice.extraVnd * quantityOf(group.id, choice.id);
      }
    }
    return total;
  }

  /// Chosen option ids with multiplicity (server counts repeats as qty).
  List<String> get optionIds => [
    for (final group in groups)
      for (final choice in group.choices)
        for (var i = 0; i < quantityOf(group.id, choice.id); i++) choice.id,
  ];

  /// Short labels of the choices, e.g. ["L", "Trân châu"].
  List<String> get labels => [
    for (final group in groups)
      for (final choice in group.choices)
        if (picked(group.id).contains(choice.id)) choice.label,
  ];

  /// Same dish + same choice → same cart line.
  String lineId(String itemId) => foodCartLineId(itemId, optionIds);
}

String foodCartLineId(String itemId, List<String> optionIds) {
  if (optionIds.isEmpty) return itemId;
  final sorted = [...optionIds]..sort();
  return '$itemId|${sorted.join(',')}';
}

/// Price delta for [optionIds] against the current catalog groups, or null when
/// the choice is no longer valid (option gone/unavailable, bounds changed).
int? foodOptionDelta(List<FoodOptionGroup> groups, List<String> optionIds) {
  // Count multiplicity (same optionId repeated = qty).
  final counts = <String, int>{};
  for (final id in optionIds) {
    counts[id] = (counts[id] ?? 0) + 1;
  }
  var delta = 0;
  var matched = 0;
  for (final group in groups) {
    var groupQty = 0;
    for (final choice in group.choices) {
      final q = counts[choice.id] ?? 0;
      if (q == 0) continue;
      if (!choice.available) return null;
      if (q > choice.maxQuantity) return null;
      groupQty += q;
      delta += choice.extraVnd * q;
      matched += q;
    }
    if (groupQty < group.minSelect || groupQty > group.maxSelect) {
      return null;
    }
  }
  return matched == optionIds.length ? delta : null;
}

/// Lenient decoder for `optionGroups` in catalog payloads (drops junk rows).
List<FoodOptionGroup> decodeFoodOptionGroups(Object? raw) {
  if (raw is! List) return const [];
  final groups = <FoodOptionGroup>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final id = entry['id'];
    final name = entry['name'];
    final minSelect = entry['minSelect'];
    final maxSelect = entry['maxSelect'];
    final rawOptions = entry['options'];
    if (id is! String ||
        name is! String ||
        minSelect is! int ||
        maxSelect is! int ||
        rawOptions is! List) {
      continue;
    }
    final choices = <FoodOptionChoice>[];
    for (final option in rawOptions) {
      if (option is! Map) continue;
      final optionId = option['id'];
      final optionName = option['name'];
      final delta = option['priceDeltaVnd'];
      if (optionId is! String || optionName is! String || delta is! num) {
        continue;
      }
      final maxQty = option['maxQuantity'];
      choices.add(
        FoodOptionChoice(
          id: optionId,
          label: optionName,
          extraVnd: delta.toInt(),
          available: option['available'] != false,
          maxQuantity: maxQty is int && maxQty >= 1 ? maxQty : 1,
        ),
      );
    }
    if (choices.isEmpty) continue;
    groups.add(
      FoodOptionGroup(
        id: id,
        title: name,
        minSelect: minSelect,
        maxSelect: maxSelect,
        choices: List.unmodifiable(choices),
      ),
    );
  }
  return List.unmodifiable(groups);
}

/// Wire form used by the catalog cache and the merchant `PUT …/options` body.
List<Map<String, Object?>> encodeFoodOptionGroups(
  List<FoodOptionGroup> groups, {
  bool includeIds = true,
}) {
  return [
    for (final group in groups)
      {
        if (includeIds && group.id.isNotEmpty) 'id': group.id,
        'name': group.title,
        'minSelect': group.minSelect,
        'maxSelect': group.maxSelect,
        'options': [
          for (final choice in group.choices)
            {
              if (includeIds && choice.id.isNotEmpty) 'id': choice.id,
              'name': choice.label,
              'priceDeltaVnd': choice.extraVnd,
              'available': choice.available,
              'maxQuantity': choice.maxQuantity,
            },
        ],
      },
  ];
}

List<FoodLineOption> decodeFoodLineOptions(Object? raw) {
  if (raw is! List) return const [];
  return List.unmodifiable([
    for (final entry in raw)
      if (entry is Map &&
          entry['groupName'] is String &&
          entry['name'] is String &&
          entry['priceDeltaVnd'] is num)
        FoodLineOption(
          groupName: entry['groupName'] as String,
          name: entry['name'] as String,
          priceDeltaVnd: (entry['priceDeltaVnd'] as num).toInt(),
          quantity: entry['quantity'] is int && (entry['quantity'] as int) > 0
              ? entry['quantity'] as int
              : 1,
          optionId: entry['optionId'] is String
              ? entry['optionId'] as String
              : null,
        ),
  ]);
}
