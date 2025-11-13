import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductSectionCard extends StatelessWidget {
  const ProductSectionCard({
    super.key,
    required this.backgroundColor,
    required this.child,
  });

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(16.w),
      child: child,
    );
  }
}

class ProductOptionViewData {
  const ProductOptionViewData({
    required this.label,
    required this.isSelected,
  });

  final String label;
  final bool isSelected;
}

class ProductOptionSection extends StatelessWidget {
  const ProductOptionSection({
    super.key,
    required this.title,
    required this.options,
    required this.onOptionTap,
    required this.textColor,
    required this.borderColor,
    required this.subtitleColor,
    this.emptyMessage,
  });

  final String title;
  final List<ProductOptionViewData> options;
  final void Function(String label) onOptionTap;
  final Color textColor;
  final Color borderColor;
  final Color subtitleColor;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          SizedBox(height: 12.h),
          Text(
            emptyMessage ?? 'Нет доступных вариантов',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: subtitleColor,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: options
              .map(
                (option) => GestureDetector(
                  onTap: () => onOptionTap(option.label),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: option.isSelected
                          ? const Color(0xFF2196F3)
                          : Colors.transparent,
                      border: Border.all(
                        color: option.isSelected
                            ? const Color(0xFF2196F3)
                            : borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      option.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: option.isSelected ? Colors.white : textColor,
                        fontWeight:
                            option.isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }
}

class SpecificationItem {
  const SpecificationItem({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}

class ProductSpecificationsSection extends StatelessWidget {
  const ProductSpecificationsSection({
    super.key,
    required this.title,
    required this.items,
    required this.textColor,
    required this.subtitleColor,
    required this.backgroundColor,
  });

  final String title;
  final List<SpecificationItem> items;
  final Color textColor;
  final Color subtitleColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ProductSectionCard(
      backgroundColor: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          if (items.isEmpty)
            Text(
              'Характеристики не указаны',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: subtitleColor,
              ),
            )
          else
            Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            item.value,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (index < items.length - 1)
                      Divider(
                        color: subtitleColor.withOpacity(0.2),
                        thickness: 1,
                        height: 16.h,
                      ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class ProductFinancialSection extends StatelessWidget {
  const ProductFinancialSection({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.subtitleColor,
    required this.downPayment,
    required this.note,
    required this.installmentSelector,
    required this.totalPrice,
    required this.monthlyText,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color subtitleColor;
  final String downPayment;
  final String note;
  final Widget installmentSelector;
  final String totalPrice;
  final String monthlyText;

  @override
  Widget build(BuildContext context) {
    return ProductSectionCard(
      backgroundColor: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Общий первоначальный взнос',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(
                downPayment,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            note,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: subtitleColor,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Срок рассрочки',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          installmentSelector,
          SizedBox(height: 24.h),
          Text(
            totalPrice,
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            monthlyText,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: const Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }
}

