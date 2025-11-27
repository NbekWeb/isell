import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class ProductFinancialSection extends StatefulWidget {
  const ProductFinancialSection({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.subtitleColor,
    required this.downPayment,
    required this.maxDownPayment,
    required this.onDownPaymentChanged,
    required this.note,
    required this.installmentSelector,
    required this.totalPrice,
    required this.monthlyText,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color subtitleColor;
  final int downPayment;
  final int maxDownPayment;
  final Function(int) onDownPaymentChanged;
  final String note;
  final Widget installmentSelector;
  final String totalPrice;
  final String monthlyText;

  @override
  State<ProductFinancialSection> createState() => _ProductFinancialSectionState();
}

class _ProductFinancialSectionState extends State<ProductFinancialSection> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.downPayment == 0 ? '' : widget.downPayment.toString(),
    );
  }

  @override
  void didUpdateWidget(ProductFinancialSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downPayment != widget.downPayment) {
      _controller.text = widget.downPayment == 0 ? '' : widget.downPayment.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProductSectionCard(
      backgroundColor: widget.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Общий первоначальный взнос',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: widget.textColor,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: widget.borderColor, width: 1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10), // Limit to 10 digits
              ],
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: widget.textColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                hintText: '0',
                hintStyle: GoogleFonts.poppins(
                  color: widget.textColor.withOpacity(0.5),
                  fontSize: 16.sp,
                ),
                prefixText: '\$',
                prefixStyle: GoogleFonts.poppins(
                  color: widget.textColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onChanged: (value) {
                // Remove any non-digit characters
                final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
                
                // Parse the value, handle empty string as 0
                final intValue = cleanValue.isEmpty ? 0 : int.tryParse(cleanValue) ?? 0;
                
                // Clamp the value between 0 and maxDownPayment
                final clampedValue = intValue.clamp(0, widget.maxDownPayment);
                
                // Update controller if the value was clamped
                if (clampedValue != intValue) {
                  final newText = clampedValue == 0 ? '' : clampedValue.toString();
                  _controller.value = _controller.value.copyWith(
                    text: newText,
                    selection: TextSelection.collapsed(offset: newText.length),
                  );
                }
                
                widget.onDownPaymentChanged(clampedValue);
              },
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.note,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: widget.subtitleColor,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Срок рассрочки',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: widget.textColor,
            ),
          ),
          SizedBox(height: 12.h),
          widget.installmentSelector,
          SizedBox(height: 24.h),
          if (widget.totalPrice.isNotEmpty) ...[
            Text(
              widget.totalPrice,
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: widget.textColor,
              ),
            ),
            SizedBox(height: 4.h),
          ],
          Text(
            widget.monthlyText,
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

