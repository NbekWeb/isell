import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/product_detail_page.dart';
import '../services/cart_service.dart';

mixin ProductCardHelpers {
  static Widget fallbackImage(
    String? name,
    Color background,
    Color textColor, {
    double? width,
    double? height,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      color: background,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Text(
        (name?.isNotEmpty ?? false) ? name! : 'Нет изображения',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: textColor,
        ),
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with ProductCardHelpers {
  int _quantity = 0;
  String? _uniqueId;

  @override
  void initState() {
    super.initState();
    _checkCartStatus();
  }

  Future<void> _checkCartStatus() async {
    final items = await CartService.getCartItems();
    final productId = _productId;

    final existingItem = items.firstWhere((item) {
      final itemId = item['id']?.toString();
      if (productId != null && itemId != null) {
        return itemId == productId;
      }
      return item['name'] == _getProductName(widget.product) &&
          item['price'] == _getProductPrice(widget.product);
    }, orElse: () => {});

    if (existingItem.isNotEmpty) {
      setState(() {
        _quantity = existingItem['quantity'] as int;
        _uniqueId = existingItem['uniqueId'] as String;
      });
    } else {
      setState(() {
        _quantity = 0;
        _uniqueId = null;
      });
    }
  }

  bool _isUsedProduct(Map<String, dynamic> product) {
    // API dan kelayotgan 'used' fieldini tekshirish
    // used: 1 = ishlatilgan (б/у)
    // used: 2 = yangi
    final used = product['used'];
    if (used != null) {
      return used == 1;
    }
    
    // Agar 'used' fieldi yo'q bo'lsa, product nomidan tekshirish (fallback)
    final productName = _getProductName(product).toLowerCase();
    final hasUsedPattern = productName.contains('b/u') || 
                          productName.contains('б/у') ||
                          productName.contains('б.у') ||
                          productName.contains('b.u');
    return hasUsedPattern;
  }

  Future<void> _openProductDetails() async {
    final productId =
        widget.product['id']?.toString() ??
        widget.product['product_id']?.toString();
    if (productId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_product_id', productId);
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailPage(product: widget.product),
        ),
      );

      await _checkCartStatus();
    }
  }

  Future<void> _updateQuantity(int delta) async {
    if (_uniqueId == null) return;

    final newQuantity = _quantity + delta;
    final isUsed = _isUsedProduct(widget.product);

    // Ishlatilgan mahsulotlar uchun miqdorni 1 ga cheklash
    if (isUsed && newQuantity > 1) {
      // Toast ko'rsatish (agar kerak bo'lsa)
      return;
    }

    if (newQuantity <= 0) {
      await CartService.removeFromCart(_uniqueId!);
      if (mounted) {
        setState(() {
          _quantity = 0;
          _uniqueId = null;
        });
      }
    } else {
      await CartService.updateQuantity(_uniqueId!, newQuantity);
      await _checkCartStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.white : Colors.black87;
    final fallbackBgColor = isDark
        ? const Color(0xFF222222)
        : const Color.fromRGBO(255, 255, 255, 1);
    final fallbackTextColor = isDark ? Colors.white : Colors.black87;
    final imageUrl = _firstImageUrl(widget.product);
    final priceText = _formatPrice(_getProductPrice(widget.product));
    final monthlyText = _formatMonthly(_getProductMonthly(widget.product));

    return GestureDetector(
      onTap: _openProductDetails,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            SizedBox(
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            ProductCardHelpers.fallbackImage(
                              _getProductName(widget.product),
                              fallbackBgColor,
                              fallbackTextColor,
                            ),
                      )
                    : ProductCardHelpers.fallbackImage(
                        _getProductName(widget.product),
                        fallbackBgColor,
                        fallbackTextColor,
                      ),
              ),
            ),

            // Product Info
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name - flexible height for 2 lines
                  SizedBox(height: 10),
                  Container(
                    constraints: BoxConstraints(
                      minHeight: 40,
                      maxHeight: 48, // Ko'proq joy berish
                    ),
                    child: Text(
                      _getProductName(widget.product),
                      style: TextStyle(
                        fontSize: 14, // Biroz kichikroq qilish
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.2, // Qator orasidagi masofani kamaytirish
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Price
                  Text(
                    priceText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 4),

                  // Monthly Payment
                  if (monthlyText != null)
                    Text(
                      'от $monthlyText в мес',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  SizedBox(height: 15),

                  // Buttons Row
                  _quantity > 0
                      ? Container(
                          width: double.infinity,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: borderColor, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => _updateQuantity(-1),
                                icon: Icon(
                                  Icons.remove,
                                  color: textColor,
                                  size: 16,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                              Expanded(
                                child: Text(
                                  '$_quantity',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _isUsedProduct(widget.product) && _quantity >= 1
                                    ? null // Ishlatilgan mahsulot uchun o'chirish
                                    : () => _updateQuantity(1),
                                icon: Icon(
                                  Icons.add,
                                  color: _isUsedProduct(widget.product) && _quantity >= 1
                                      ? textColor.withOpacity(0.3)
                                      : textColor,
                                  size: 16,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: _openProductDetails,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    'Подробнее',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                        ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _firstImageUrl(Map<String, dynamic> product) {
    // Check direct image field first
    if (product['image'] is String && product['image'].isNotEmpty) {
      return product['image'] as String;
    }

    // Check variations for images
    final variations = product['variations'];
    if (variations is List && variations.isNotEmpty) {
      for (final variation in variations) {
        if (variation['image'] is String && variation['image'].isNotEmpty) {
          return variation['image'] as String;
        }
      }
    }

    // Fallback to old structure
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['image'] is String) {
        return first['image'] as String;
      } else if (first is String) {
        return first;
      }
    }
    return null;
  }

  String? get _productId {
    final id = widget.product['product_id'];
    return id?.toString();
  }

  double? _parseUsdValue(dynamic value) {
    if (value == null) return null;

    if (value is num) return value.toDouble();

    final str = value.toString().trim().replaceAll(',', '.');
    if (str.isEmpty) return null;

    final double? parsed = double.tryParse(str);
    if (parsed != null) return parsed;

    final sanitized = str.replaceAll(RegExp(r'[^\d]'), '');
    if (sanitized.isEmpty) return null;
    final int? intValue = int.tryParse(sanitized);
    return intValue?.toDouble();
  }

  String _formatUsd(num amount) {
    final isWhole = amount == amount.roundToDouble();
    final formatted = isWhole
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;
    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i != 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(integerPart[i]);
    }
    return decimalPart != null
        ? '\$${buffer.toString()}.$decimalPart'
        : '\$${buffer.toString()}';
  }

  String _formatPrice(dynamic price) {
    final amount = _parseUsdValue(price);
    if (amount == null) return _formatUsd(0);
    return _formatUsd(amount);
  }

  String? _formatMonthly(dynamic monthly) {
    final amount = _parseUsdValue(monthly);
    if (amount == null) return null;
    return _formatUsd(amount);
  }

  String _getProductName(Map<String, dynamic> product) {
    return product['product_name']?.toString() ??
        product['name']?.toString() ??
        'Без названия';
  }

  dynamic _getProductPrice(Map<String, dynamic> product) {
    // First check if there's a direct price field (for backward compatibility)
    if (product['price'] != null) {
      return product['price'];
    }

    // Check variations for price
    final variations = product['variations'];
    if (variations is List && variations.isNotEmpty) {
      // Find the default variation first
      final defaultVariation = variations.firstWhere(
        (v) => v['is_default'] == true,
        orElse: () => variations.first,
      );
      return defaultVariation['price'];
    }

    return 0;
  }

  dynamic _getProductMonthly(Map<String, dynamic> product) {
    // Check if there's a direct monthly field (for backward compatibility)
    if (product['monthly'] != null) {
      return product['monthly'];
    }

    // For new structure, we might not have monthly payments info
    // You can calculate it based on price or return null
    return null;
  }
}
