import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductQuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;
  final bool isIncreaseDisabled;

  const ProductQuantitySelector({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    this.isIncreaseDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF2196F3);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        color: accentColor,
        child: Row(
          children: [
            _buildQuantityControlButton(
              icon: Icons.remove,
              onTap: onDecrease,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$quantity',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            _buildQuantityControlButton(
              icon: Icons.add,
              onTap: onIncrease,
              isDisabled: isIncreaseDisabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: 56.w,
      height: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          child: Center(
            child: Icon(
              icon,
              color: isDisabled ? Colors.white.withOpacity(0.5) : Colors.white,
              size: 24.w,
            ),
          ),
        ),
      ),
    );
  }
}
