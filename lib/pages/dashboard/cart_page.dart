import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cart_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> cartItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
    });
    final items = await CartService.getCartItems();
    setState(() {
      cartItems = items;
      _isLoading = false;
    });
  }

  Future<void> _updateQuantity(String uniqueId, int delta) async {
    final item = cartItems.firstWhere((item) => item['uniqueId'] == uniqueId);
    final newQuantity = (item['quantity'] as int) + delta;
    
    if (newQuantity <= 0) {
      await CartService.removeFromCart(uniqueId);
    } else {
      await CartService.updateQuantity(uniqueId, newQuantity);
    }
    
    await _loadCartItems();
  }

  Future<void> _removeItem(String uniqueId) async {
    await CartService.removeFromCart(uniqueId);
    await _loadCartItems();
  }

  int _calculateTotal() {
    return cartItems.fold(0, (sum, item) {
      final price = item['price'] is int 
          ? item['price'] as int 
          : int.tryParse(item['price'].toString().replaceAll(',', '').replaceAll(' ', '')) ?? 0;
      final quantity = item['quantity'] is int 
          ? item['quantity'] as int 
          : int.tryParse(item['quantity'].toString()) ?? 0;
      return sum + (price * quantity);
    });
  }

  int _getPriceAsInt(Map<String, dynamic> item) {
    if (item['price'] is int) {
      return item['price'] as int;
    }
    return int.tryParse(item['price'].toString().replaceAll(',', '').replaceAll(' ', '')) ?? 0;
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.white.withOpacity(0.1) : (Colors.grey[300] ?? Colors.grey);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : const Color(0xFF2196F3),
              ),
            )
          : cartItems.isEmpty
              ? _buildEmptyCart(isDark, textColor)
              : _buildCartWithItems(textColor, cardColor, borderColor, dividerColor),
    );
  }

  Widget _buildEmptyCart(bool isDark, Color textColor) {
    final circleColor = isDark ? const Color(0xFF333333) : (Colors.grey[200] ?? Colors.grey);
    final subtitleColor = isDark ? textColor.withOpacity(0.7) : textColor.withOpacity(0.6);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108.w,
            height: 108.w,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 44.w,
                color: const Color(0xFF2196F3),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Корзина пуста',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Добавьте товары из каталога',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCartWithItems(Color textColor, Color cardColor, Color borderColor, Color dividerColor) {
    final total = _calculateTotal();
    final itemCount = cartItems.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cart Items
                ...cartItems.map((item) {
                  return _buildCartItem(item, textColor, cardColor, borderColor);
                }),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
        // Order Summary
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(
              top: BorderSide(color: dividerColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Ваш заказ',
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Товары ($itemCount):',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${_formatNumber(total)} сум',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Доставка:',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Бесплатно',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Итого:',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${_formatNumber(total)} сум',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to checkout
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Оформить заказ',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, Color textColor, Color cardColor, Color borderColor) {
    final uniqueId = item['uniqueId'] as String;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: borderColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // First Row: Image, Name, Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: _buildCartImage(item['image']),
                  ),
                  SizedBox(width: 12.w),
                  // Product Details
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 40.w), // Space for delete icon
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_variantDescription(item).isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              _variantDescription(item),
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: textColor.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 4.h),
                          Text(
                            '${_formatNumber(_getPriceAsInt(item))} сум',
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Second Row: Quantity Control (centered)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus Button
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor, width: 1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _updateQuantity(uniqueId, -1),
                      icon: Icon(Icons.remove, color: textColor, size: 18.w),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Quantity Display
                  Text(
                    '${item['quantity']}',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Plus Button
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor, width: 1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _updateQuantity(uniqueId, 1),
                      icon: Icon(Icons.add, color: textColor, size: 18.w),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Delete Button - Top Right
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => _removeItem(uniqueId),
              icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.w),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

  Widget _buildCartImage(dynamic image) {
    final imageUrl = image?.toString();
    final placeholder = Image.asset(
      'assets/img/product.png',
      width: 80.w,
      height: 80.w,
      fit: BoxFit.cover,
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 80.w,
        height: 80.w,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Image.asset(
      imageUrl,
      width: 80.w,
      height: 80.w,
      fit: BoxFit.cover,
    );
  }

  String _variantDescription(Map<String, dynamic> item) {
    final parts = <String>[];
    final color = item['selectedColor']?.toString();
    final storage = item['selectedStorage']?.toString();
    final sim = item['selectedSim']?.toString();

    if (color != null && color.isNotEmpty) {
      parts.add(color);
    }
    if (storage != null && storage.isNotEmpty) {
      parts.add(storage);
    }
    if (sim != null && sim.isNotEmpty) {
      parts.add(sim);
    }

    return parts.join(' • ');
  }

