import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'product_quantity_selector.dart';

class ProductBottomActions extends StatelessWidget {
  final int cartQuantity;
  final VoidCallback onAddToCart;
  final VoidCallback onNavigateToCart;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;
  final bool isIncreaseDisabled;

  const ProductBottomActions({
    super.key,
    required this.cartQuantity,
    required this.onAddToCart,
    required this.onNavigateToCart,
    required this.onDecrease,
    required this.onIncrease,
    this.isIncreaseDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cartQuantity > 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 50.h,
            child: ProductQuantitySelector(
              quantity: cartQuantity,
              onDecrease: onDecrease,
              onIncrease: onIncrease,
              isIncreaseDisabled: isIncreaseDisabled,
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 48.h,
            child: OutlinedButton(
              onPressed: onNavigateToCart,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2196F3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Перейти в корзину',
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: onAddToCart,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/svg/bag.svg',
              width: 24.w,
              height: 24.w,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Добавить в корзину',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
