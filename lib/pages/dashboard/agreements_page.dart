import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class AgreementsPage extends StatelessWidget {
  const AgreementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final circleColor = isDark ? const Color(0xFF333333) : (Colors.grey[200] ?? Colors.grey);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
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
                  Icons.description_outlined,
                  size: 44.w,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Договор нет',
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

