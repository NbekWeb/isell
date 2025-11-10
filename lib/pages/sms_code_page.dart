import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_toast.dart';

class SMSCodePage extends StatefulWidget {
  final String phoneNumber;

  const SMSCodePage({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<SMSCodePage> createState() => _SMSCodePageState();
}

class _SMSCodePageState extends State<SMSCodePage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
    (index) => FocusNode(),
  );

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1) {
      _controllers[index].text = value;
      // Move to next field
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    } else if (value.isEmpty) {
      _controllers[index].text = '';
      // Move to previous field if current is empty
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyCode() {
    final code = _controllers.map((c) => c.text).join();
    
    if (code.length == 4) {
      if (code == '1234') {
        CustomToast.show(
          context,
          message: 'Вы успешно вошли в систему',
          isSuccess: true,
        );
        // Navigate to home page
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      } else {
        CustomToast.show(
          context,
          message: 'SMS код неверный',
          isSuccess: false,
        );
        // Clear all fields
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        for (var focusNode in _focusNodes) {
          focusNode.unfocus();
        }
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
                        'Введите отправленной код',
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
                      SizedBox(height: 60.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(4, (index) {
                          return SizedBox(
                            width: 70.w,
                            height: 70.w,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                              style: GoogleFonts.poppins(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2196F3),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                              onChanged: (value) => _onCodeChanged(index, value),
                              onTap: () {
                                // Select all text when tapped
                                _controllers[index].selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _controllers[index].text.length,
                                );
                              },
                              onSubmitted: (value) {
                                if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: () {
                            final code = _controllers.map((c) => c.text).join();
                            if (code.length == 4) {
                              _verifyCode();
                            } else {
                              // Focus on first empty field
                              for (int i = 0; i < 4; i++) {
                                if (_controllers[i].text.isEmpty) {
                                  _focusNodes[i].requestFocus();
                                  break;
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
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

