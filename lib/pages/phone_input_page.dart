import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/custom_toast.dart';
import 'sms_code_page.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    // Set initial value with +998 prefix
    _phoneController.text = '+998 ';
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text.replaceAll(' ', '');
    final isValid = text.length == 13 && text.startsWith('+998');
    
    if (_isButtonEnabled != isValid) {
      setState(() {
        _isButtonEnabled = isValid;
      });
    }
  }

  String _formatPhoneNumber(String value) {
    // Remove all non-digit characters except +
    String digitsOnly = value.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Ensure it starts with +998
    if (!digitsOnly.startsWith('+998')) {
      digitsOnly = '+998';
    }
    
    // Limit to +998 + 9 digits
    if (digitsOnly.length > 13) {
      digitsOnly = digitsOnly.substring(0, 13);
    }
    
    // Format: +998 91 999 99 99
    if (digitsOnly.length > 4) {
      String formatted = '+998';
      String remaining = digitsOnly.substring(4);
      
      if (remaining.length >= 2) {
        formatted += ' ${remaining.substring(0, 2)}';
        remaining = remaining.substring(2);
        
        if (remaining.length >= 3) {
          formatted += ' ${remaining.substring(0, 3)}';
          remaining = remaining.substring(3);
          
          if (remaining.length >= 2) {
            formatted += ' ${remaining.substring(0, 2)}';
            remaining = remaining.substring(2);
            
            if (remaining.length >= 2) {
              formatted += ' ${remaining.substring(0, 2)}';
            } else if (remaining.isNotEmpty) {
              formatted += ' $remaining';
            }
          } else if (remaining.isNotEmpty) {
            formatted += ' $remaining';
          }
        } else if (remaining.isNotEmpty) {
          formatted += ' $remaining';
        }
      } else if (remaining.isNotEmpty) {
        formatted += ' $remaining';
      }
      
      return formatted;
    }
    
    return digitsOnly;
  }

  Future<void> _onContinue() async {
    if (!_isButtonEnabled || _isLoading) return;

    // MyID SDK will handle camera permission request itself
    // No need to check permission here
    
    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumber = _phoneController.text.replaceAll(' ', '');
      
      final result = await AuthService.login(phoneNumber: phoneNumber);

      if (result != null && result['success'] == true) {
      CustomToast.show(
        context,
          message: 'SMS код отправлен',
        isSuccess: true,
      );
      
      // Navigate to SMS code page
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SmsCodePage(phoneNumber: phoneNumber),
        ),
      );
      } else {
        final errorMessage = result?['error'] ?? 'Ошибка при отправке кода';
        CustomToast.show(
          context,
          message: errorMessage,
          isSuccess: false,
        );
      }
    } catch (e) {
      CustomToast.show(
        context,
        message: 'Произошла ошибка при отправке кода',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: textColor,
          ),
                      onPressed: () => Navigator.pop(context),
                    ),
        title: Image.asset(
                          'assets/img/logo.png',
          height: 32.h,
          fit: BoxFit.contain,
                      ),
        centerTitle: true,
                ),
      body: Padding(
        padding: EdgeInsets.all(24.w),
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 40.h),
            
            // Title
                      Text(
                        'Введите номер телефона',
              textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                fontSize: 24.sp,
                          fontWeight: FontWeight.w600,
                color: textColor,
                        ),
                      ),
            
                      SizedBox(height: 8.h),
            
            // Subtitle
                      Text(
                        'Мы отправляем смс код',
              textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                color: subtitleColor,
                        ),
                      ),
            
                      SizedBox(height: 40.h),
            
            // Phone input label
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                        'Номер телефона',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                        ),
                      ),
            
            SizedBox(height: 8.h),
            
            // Phone input field
                      Container(
                        decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF2196F3),
                  width: 2,
                ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                          ),
                          decoration: InputDecoration(
                  hintText: '+998 91 999 99 99',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    color: subtitleColor,
                  ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 16.h,
                            ),
                          ),
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final formatted = _formatPhoneNumber(newValue.text);
                    return TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }),
                ],
                        ),
                      ),
            
                      const Spacer(),
            
            // Continue button
                      SizedBox(
                        width: double.infinity,
              height: 56.h,
                        child: ElevatedButton(
                onPressed: (_isButtonEnabled && !_isLoading) ? _onContinue : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                  disabledBackgroundColor: isDark 
                      ? const Color(0xFF2196F3).withOpacity(0.5)
                      : Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                  elevation: 0,
                          ),
                child: _isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                            'Продолжить',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                          color: (_isButtonEnabled && !_isLoading) ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 40.h),
            ],
        ),
      ),
    );
  }
}