import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_toast.dart';
import 'sms_code_page.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneController.text = '+998 ';
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String value) {
    // Remove all non-digit characters
    String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // If starts with 998, keep it, otherwise add 998
    if (digits.startsWith('998')) {
      digits = digits.substring(3);
    }
    
    // Limit to 9 digits (Uzbekistan mobile number)
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }
    
    // Format: +998 XX XXX XX XX
    if (digits.isEmpty) {
      return '+998 ';
    } else if (digits.length <= 2) {
      return '+998 $digits';
    } else if (digits.length <= 5) {
      return '+998 ${digits.substring(0, 2)} ${digits.substring(2)}';
    } else if (digits.length <= 7) {
      return '+998 ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
    } else {
      return '+998 ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 7)} ${digits.substring(7)}';
    }
  }

  void _onPhoneChanged(String value) {
    final formatted = _formatPhoneNumber(value);
    if (_phoneController.text != formatted) {
      setState(() {
        _phoneController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      });
    } else {
      setState(() {});
    }
  }

  bool _isValidPhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length == 12 && digits.startsWith('998');
  }

  void _onContinue() {
    if (_isValidPhone()) {
      // Show toast
      CustomToast.show(
        context,
        message: 'SMS отправлен',
        isSuccess: true,
      );
      
      // Navigate to SMS code page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SMSCodePage(phoneNumber: _phoneController.text),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/img/logo.png',
                          height: 24.h,
                        ),
                      ),
                    ),
                    SizedBox(width: 48.w), // Balance for back button
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 40.h),
                      Text(
                        'Введите номер телефона',
                        style: GoogleFonts.poppins(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Мы отправляем смс код',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                      SizedBox(height: 40.h),
                      Text(
                        'Номер телефона',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+]')),
                          ],
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 16.h,
                            ),
                          ),
                          onChanged: _onPhoneChanged,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: _isValidPhone() ? _onContinue : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            disabledBackgroundColor: Colors.grey[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Продолжить',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

