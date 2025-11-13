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

  const ProductCard({
    super.key,
    required this.product,
  });

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

    final existingItem = items.firstWhere(
      (item) {
        final itemId = item['id']?.toString();
        if (productId != null && itemId != null) {
          return itemId == productId;
        }
        return item['name'] == widget.product['name'] &&
            item['price'] == widget.product['price'];
      },
      orElse: () => {},
    );

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

  Future<void> _openProductDetails() async {
    final productId = widget.product['id']?.toString() ??
        widget.product['product_id']?.toString();
    if (productId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_product_id', productId);
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailPage(
            product: widget.product,
          ),
        ),
      );

      await _checkCartStatus();
    }
  }

  Future<void> _updateQuantity(int delta) async {
    if (_uniqueId == null) return;

    final newQuantity = _quantity + delta;
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
    final fallbackBgColor = isDark ? const Color(0xFF222222) : const Color.fromRGBO(255, 255, 255, 1);
    final fallbackTextColor = isDark ? Colors.white : Colors.black87;
    final imageUrl = _firstImageUrl(widget.product);
    final priceText = _formatPrice(widget.product['price']);
    final monthlyText = _formatMonthly(widget.product['monthly']);
    
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
                      errorBuilder: (_, __, ___) => ProductCardHelpers.fallbackImage(
                        widget.product['name']?.toString(),
                        fallbackBgColor,
                        fallbackTextColor,
                      ),
                    )
                  : ProductCardHelpers.fallbackImage(
                      widget.product['name']?.toString(),
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
                // Product Name - fixed height for 2 lines
                SizedBox(height: 10),
                SizedBox(
                  height: 40, // Approximate height for 2 lines of text
                  child: Text(
                    widget.product['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
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
                              onPressed: () => _updateQuantity(1),
                              icon: Icon(
                                Icons.add,
                                color: textColor,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          // Details Button
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: _openProductDetails,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: borderColor, width: 1),
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
                          ),
                          SizedBox(width: 10),

                          // Add to Cart Button
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _openProductDetails,
                              icon: Icon(
                                Icons.shopping_cart,
                                color: Colors.white,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
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
    final id = widget.product['id'] ?? widget.product['product_id'];
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
    final formatted =
        isWhole ? amount.round().toString() : amount.toStringAsFixed(2);
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
}

