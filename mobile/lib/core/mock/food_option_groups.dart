import '../../features/food/domain/entities/food_options.dart';

/// Mock-mode option groups for the demo "Bún bò đặc biệt" (USE_MOCK_DATA only).
/// Live builds read `optionGroups` from the store catalog (DEC-PROD-033).
const mockBunOptionGroups = <FoodOptionGroup>[
  FoodOptionGroup(
    id: 'size',
    title: 'Chọn kích cỡ',
    minSelect: 1,
    maxSelect: 1,
    choices: [
      FoodOptionChoice(id: 'regular', label: 'Thường'),
      FoodOptionChoice(id: 'large', label: 'Lớn', extraVnd: 10000),
    ],
  ),
  FoodOptionGroup(
    id: 'spice',
    title: 'Độ cay',
    minSelect: 1,
    maxSelect: 1,
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
    minSelect: 0,
    maxSelect: 3,
    choices: [
      FoodOptionChoice(id: 'nam', label: 'Thêm nạm', extraVnd: 15000),
      FoodOptionChoice(id: 'gan', label: 'Thêm gân', extraVnd: 15000),
      FoodOptionChoice(id: 'cha', label: 'Thêm chả cua', extraVnd: 12000),
    ],
  ),
];
