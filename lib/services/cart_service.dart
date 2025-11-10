import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CartService {
  static const String _cartKey = 'cart_items';
  static const String _cartCountKey = 'cart_count';

  // Generate unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Get all cart items
  static Future<List<Map<String, dynamic>>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    if (cartJson == null) {
      return [];
    }
    final List<dynamic> cartList = json.decode(cartJson);
    return cartList.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  // Save cart items
  static Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = json.encode(items);
    await prefs.setString(_cartKey, cartJson);
    await _updateCartCount(items);
  }

  // Add item to cart
  static Future<void> addToCart(Map<String, dynamic> product) async {
    final items = await getCartItems();
    final productId = product['id']?.toString();
    final selectedColor = product['selectedColor'];
    final selectedStorage = product['selectedStorage'];
    final selectedSim = product['selectedSim'];

    // Check if product already exists (by unique id or name+price)
    final existingIndex = items.indexWhere((item) => 
      item['uniqueId'] == product['uniqueId'] || 
      (productId != null && item['id']?.toString() == productId &&
        item['selectedColor'] == selectedColor &&
        item['selectedStorage'] == selectedStorage &&
        item['selectedSim'] == selectedSim) ||
      (item['name'] == product['name'] && item['price'] == product['price'] &&
        item['selectedColor'] == selectedColor &&
        item['selectedStorage'] == selectedStorage &&
        item['selectedSim'] == selectedSim)
    );

    if (existingIndex != -1) {
      // Update quantity if exists
      items[existingIndex]['quantity'] = (items[existingIndex]['quantity'] as int) + 1;
    } else {
      // Add new item with unique ID
      final newItem = {
        'id': productId,
        'name': product['name'],
        'price': product['price'],
        'image': product['image'],
        'selectedColor': selectedColor,
        'selectedStorage': selectedStorage,
        'selectedSim': selectedSim,
        'uniqueId': product['uniqueId'] ?? generateId(),
        'quantity': product['quantity'] ?? 1,
      };
      items.add(newItem);
    }

    await saveCartItems(items);
  }

  // Update item quantity
  static Future<void> updateQuantity(String uniqueId, int quantity) async {
    final items = await getCartItems();
    final index = items.indexWhere((item) => item['uniqueId'] == uniqueId);
    
    if (index != -1) {
      if (quantity <= 0) {
        items.removeAt(index);
      } else {
        items[index] = {
          ...items[index],
          'quantity': quantity,
        };
      }
      await saveCartItems(items);
    }
  }

  // Remove item from cart
  static Future<void> removeFromCart(String uniqueId) async {
    final items = await getCartItems();
    items.removeWhere((item) => item['uniqueId'] == uniqueId);
    await saveCartItems(items);
  }

  // Get cart count
  static Future<int> getCartCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cartCountKey) ?? 0;
  }

  // Update cart count
  static Future<void> _updateCartCount(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final totalQuantity = items.fold(0, (sum, item) => sum + (item['quantity'] as int));
    await prefs.setInt(_cartCountKey, totalQuantity);
  }

  // Clear cart
  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
    await prefs.remove(_cartCountKey);
  }
}

