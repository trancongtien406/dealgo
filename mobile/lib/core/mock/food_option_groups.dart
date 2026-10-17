import 'mock_seed.dart';

class FoodOptionChoice {
  const FoodOptionChoice({
    required this.id,
    required this.label,
    this.extraVnd = 0,
  });

  final String id;
  final String label;
  final int extraVnd;
}

class FoodOptionGroup {
  const FoodOptionGroup({
    required this.id,
    required this.title,
    required this.required,
    required this.choices,
    this.multi = false,
  });

  final String id;
  final String title;
  final bool required;
  final bool multi;
  final List<FoodOptionChoice> choices;
}

/// Demo option groups for mock/catalog UX. Live API has no option contract yet.
List<FoodOptionGroup> mockFoodOptionGroups(String itemId) {
  if (itemId != mockItemBun) {
    return const [];
  }
  return const [
    FoodOptionGroup(
      id: 'size',
      title: 'Chọn kích cỡ',
      required: true,
      choices: [
        FoodOptionChoice(id: 'regular', label: 'Thường'),
        FoodOptionChoice(id: 'large', label: 'Lớn', extraVnd: 10000),
      ],
    ),
    FoodOptionGroup(
      id: 'spice',
      title: 'Độ cay',
      required: true,
      choices: [
        FoodOptionChoice(id: 'none', label: 'Không cay'),
        FoodOptionChoice(id: 'mild', label: 'Ít cay'),
        FoodOptionChoice(id: 'medium', label: 'Vừa'),
        FoodOptionChoice(id: 'hot', label: 'Cay nhiều'),
      ],
    ),
    FoodOptionGroup(
      id: 'topping',
      title: 'Thêm topping',
      required: false,
      multi: true,
      choices: [
        FoodOptionChoice(id: 'nam', label: 'Thêm nạm', extraVnd: 15000),
        FoodOptionChoice(id: 'gan', label: 'Thêm gân', extraVnd: 15000),
        FoodOptionChoice(id: 'cha', label: 'Thêm chả cua', extraVnd: 12000),
      ],
    ),
  ];
}
