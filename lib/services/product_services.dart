import 'package:dio/dio.dart';

import 'api_service.dart';

class ProductServices {
  static Future<Map<String, dynamic>> getAllProducts({
    String? name,
    int? category,
    int page = 1,
  }) async {
    try {
      final Response response = await ApiService.request(
        url: 'products/',
        method: 'GET',
        queryParameters: {
          if (name != null && name.isNotEmpty) 'name': name,
          if (category != null) 'category': category,
          'page': page,
          'page_size': 10
        },
      );

      final data = response.data;

      if (data is Map<String, dynamic>) {
        final results = data['results'] ?? [];
        final totalPages = data['total_pages'] ?? 1;
        
        return {
          'results': results is List
              ? results
                  .map<Map<String, dynamic>>(
                    (item) => Map<String, dynamic>.from(item as Map),
                  )
                  .toList()
              : <Map<String, dynamic>>[],
          'total_pages': totalPages is int ? totalPages : 1,
        };
      }
    } catch (_) {
      // ignore
    }

    return {
      'results': <Map<String, dynamic>>[],
      'total_pages': 1,
    };
  }

  static Future<Map<String, dynamic>?> getProductFilter({
    required int productId,
    String? colorName,
    String? storageName,
    String? simCardName,
  }) async {
    try {
      final Response response = await ApiService.request(
        url: 'products/$productId/filter/',
        method: 'GET',
        queryParameters: {
          if (colorName != null && colorName.isNotEmpty) 'color_name': colorName,
          if (storageName != null && storageName.isNotEmpty) 'storage_name': storageName,
          if (simCardName != null && simCardName.isNotEmpty) 'sim_card_name': simCardName,
        },
      );

      final data = response.data;

      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {
      // ignore
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final Response response = await ApiService.request(
        url: 'products/banners/',
        method: 'GET',
      );

      final data = response.data;

      if (data is List) {
        final banners = data
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .where((banner) => banner['is_active'] == true)
            .toList();

        // Sort banners: if all orders are 0, sort by id; otherwise sort by order
        final allOrdersZero = banners.every((b) => (b['order'] as int? ?? 0) == 0);
        
        if (allOrdersZero) {
          banners.sort((a, b) => (a['id'] as int? ?? 0).compareTo(b['id'] as int? ?? 0));
        } else {
          banners.sort((a, b) {
            final orderA = a['order'] as int? ?? 0;
            final orderB = b['order'] as int? ?? 0;
            if (orderA == 0) return 1; // Put 0 orders at the end
            if (orderB == 0) return -1;
            return orderA.compareTo(orderB);
          });
        }

        return banners;
      }
    } catch (_) {
      // ignore
    }

    return <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final Response response = await ApiService.request(
        url: 'products/categories/',
        method: 'GET',
      );

      final data = response.data;

      if (data is List) {
        return data
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();
      }
    } catch (_) {
      // ignore
    }

    return <Map<String, dynamic>>[];
  }
}

