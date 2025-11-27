import 'package:dio/dio.dart';
import 'api_service.dart';

class OrderServices {
  static Future<List<Map<String, dynamic>>> getCompanyAddresses() async {
    try {
      print('🔵 Fetching company addresses from: info/company-addresses/');
      final Response response = await ApiService.request(
        url: 'info/company-addresses/',
        method: 'GET',
      );
      print('🔵 Company Addresses API Response: ${response.data}');
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
