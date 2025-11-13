import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;
  final Color textColor;
  final Color borderColor;
  final Color hintColor;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.textColor,
    required this.borderColor,
    required this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            icon: Icon(
              Icons.chevron_left,
              color: currentPage > 1 ? textColor : hintColor,
            ),
          ),
          SizedBox(width: 12.w),
          // Page numbers
          ..._buildPaginationButtons(),
          SizedBox(width: 12.w),
          // Next button
          IconButton(
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: Icon(
              Icons.chevron_right,
              color: currentPage < totalPages ? textColor : hintColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPaginationButtons() {
    final tokens = _buildPaginationSequence();
    final List<Widget> buttons = [];

    for (final token in tokens) {
      if (token is int) {
        buttons.add(_buildPageButton(token));
      } else {
        buttons.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              '...',
              style: TextStyle(color: hintColor, fontSize: 14.sp),
            ),
          ),
        );
      }
    }

    return buttons;
  }

  List<dynamic> _buildPaginationSequence() {
    if (totalPages <= 5) {
      return List<int>.generate(totalPages, (index) => index + 1);
    }

    final List<dynamic> sequence = <dynamic>[1];

    if (currentPage <= 2) {
      // Show: 1 2 3 ... last (when on page 1 or 2)
      sequence.add(2);
      sequence.add(3);
      if (totalPages > 4) {
        sequence.add('ellipsis');
      }
    } else if (currentPage >= totalPages - 1) {
      // Show: 1 ... (last-2) (last-1) last (when on last or second-to-last page)
      sequence.add('ellipsis');
      for (int i = totalPages - 2; i <= totalPages; i++) {
        sequence.add(i);
      }
    } else {
      // Show: 1 ... (current-1) current (current+1) ... last
      sequence.add('ellipsis');
      sequence.add(currentPage - 1);
      sequence.add(currentPage);
      sequence.add(currentPage + 1);
      sequence.add('ellipsis');
    }

    if (!sequence.contains(totalPages)) {
      sequence.add(totalPages);
    }

    return sequence;
  }

  Widget _buildPageButton(int pageNumber) {
    final isActive = pageNumber == currentPage;
    return GestureDetector(
      onTap: () => onPageChanged(pageNumber),
      child: Container(
        width: 32.w,
        height: 32.w,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2196F3)
              : Colors.transparent,
          border: Border.all(
            color: isActive
                ? const Color(0xFF2196F3)
                : borderColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Center(
          child: Text(
            '$pageNumber',
            style: TextStyle(
              color: isActive ? Colors.white : textColor,
              fontSize: 14.sp,
              fontWeight: isActive
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

