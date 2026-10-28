import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/entities/food_category.dart';

/// Public endpoint (no Authorization header), cached 5 min by the API.
class DioFoodCategoryRepository implements FoodCategoryRepository {
  DioFoodCategoryRepository({required this.dio});

  final Dio dio;

  @override
  Future<List<FoodCategory>> list() async {
    try {
      final response = await dio.get<Object?>(ApiPaths.publicFoodCategories);
      return decodeFoodCategories(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

/// Tests and mock builds: the nine categories the migration seeds.
class FakeFoodCategoryRepository implements FoodCategoryRepository {
  FakeFoodCategoryRepository({List<FoodCategory>? categories, this.error})
    : categories = categories ?? seeded;

  final List<FoodCategory> categories;
  final Object? error;
  int calls = 0;

  static const seeded = [
    FoodCategory(
      code: 'pho',
      nameVi: 'Phở',
      nameEn: 'Pho',
      icon: 'soup',
      tone: 'orange',
    ),
    FoodCategory(
      code: 'noodles',
      nameVi: 'Bún, mì',
      nameEn: 'Noodles',
      icon: 'cooking-pot',
      tone: 'amber',
    ),
    FoodCategory(
      code: 'rice',
      nameVi: 'Cơm',
      nameEn: 'Rice',
      icon: 'utensils',
      tone: 'red',
    ),
    FoodCategory(
      code: 'banh_mi',
      nameVi: 'Bánh mì',
      nameEn: 'Banh mi',
      icon: 'sandwich',
      tone: 'brown',
    ),
    FoodCategory(
      code: 'tea',
      nameVi: 'Trà sữa',
      nameEn: 'Milk tea',
      icon: 'cup-soda',
      tone: 'pink',
    ),
    FoodCategory(
      code: 'cafe',
      nameVi: 'Cà phê',
      nameEn: 'Coffee',
      icon: 'coffee',
      tone: 'blue',
    ),
    FoodCategory(
      code: 'fast_food',
      nameVi: 'Ăn nhanh',
      nameEn: 'Fast food',
      icon: 'hamburger',
      tone: 'green',
    ),
    FoodCategory(
      code: 'snack',
      nameVi: 'Ăn vặt',
      nameEn: 'Snacks',
      icon: 'popcorn',
      tone: 'purple',
    ),
    FoodCategory(
      code: 'mart',
      nameVi: 'Siêu thị',
      nameEn: 'Grocery',
      icon: 'shopping-cart',
      tone: 'indigo',
    ),
  ];

  @override
  Future<List<FoodCategory>> list() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return categories;
  }
}
