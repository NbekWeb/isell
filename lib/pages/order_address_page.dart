import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/order_services.dart';
import '../widgets/custom_toast.dart';

class OrderAddressPage extends StatefulWidget {
  const OrderAddressPage({super.key});

  @override
  State<OrderAddressPage> createState() => _OrderAddressPageState();
}

class _OrderAddressPageState extends State<OrderAddressPage> {
  String _selectedDeliveryType = 'pickup'; // Default 'pickup'
  int? _selectedCompanyId;
  String _address = '';
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isLoadingAddresses = true;
  List<Map<String, dynamic>> _companyAddresses = [];
  int? _orderId;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: _address);
    _loadOrderId();
    _fetchCompanyAddresses();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }


  Future<void> _loadOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getInt('lastOrderedId');
    if (orderId != null) {
      setState(() {
        _orderId = orderId;
      });
    }
  }

  Future<void> _fetchCompanyAddresses() async {
    print('🔵 Fetching company addresses...');
    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      final addresses = await OrderServices.getCompanyAddresses();
      print('📥 Company addresses received: ${addresses.length}');
      print('📋 Addresses: $addresses');

      if (mounted) {
        setState(() {
          _companyAddresses = addresses;
          _isLoadingAddresses = false;
          
          // Set default to first office if available
          if (addresses.isNotEmpty && _selectedDeliveryType == 'pickup') {
            _selectedCompanyId = addresses[0]['id'] as int?;
            print('✅ Default office selected: ${_selectedCompanyId}');
          }
        });
      }
    } catch (e) {
      print('❌ Error fetching company addresses: $e');
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
        CustomToast.show(
          context,
          message: 'Ошибка загрузки адресов',
          isSuccess: false,
        );
      }
    }
  }

  void _selectPickup() {
    setState(() {
      _selectedDeliveryType = 'pickup';
      _address = '';
      _addressController.text = '';
      _latitude = null;
      _longitude = null;
      
      // Set default to first office if available
      if (_companyAddresses.isNotEmpty) {
        _selectedCompanyId = _companyAddresses[0]['id'] as int?;
      }
    });
  }

  void _selectDelivery() {
    setState(() {
      _selectedDeliveryType = 'delivery';
      _selectedCompanyId = null;
    });
  }

  void _showAdminContactModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B7EFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: const Color(0xFF1B7EFF),
                  size: 32.w,
                ),
              ),
              SizedBox(height: 24.h),
              // Title
              Text(
                'Информация',
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16.h),
              // Message
              Text(
                'Administrator tez orada sizga bo\'glanadi. Shundan so\'ng buyurtma dogovor qismida ko\'rinadi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  color: textColor.withOpacity(0.8),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24.h),
              // OK button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B7EFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'OK',
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
      ),
    );
  }

  void _showCompanyAddressesModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            // Title
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'Выберите адрес магазина',
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            // Addresses list
            Expanded(
              child: _isLoadingAddresses
                  ? Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF1B7EFF),
                      ),
                    )
                  : _companyAddresses.isEmpty
                      ? Center(
                          child: Text(
                            'Адреса не найдены',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: _companyAddresses.length,
                          itemBuilder: (context, index) {
                            final address = _companyAddresses[index];
                            final isSelected = _selectedCompanyId == address['id'];

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCompanyId = address['id'] as int;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                margin: EdgeInsets.only(bottom: 12.h),
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF1B7EFF).withOpacity(0.1)
                                      : cardColor,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1B7EFF)
                                        : (borderColor ?? Colors.grey),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address['name']?.toString() ?? 'Адрес',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      address['address']?.toString() ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.sp,
                                        color: textColor.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  






  Future<void> _submitAddress() async {
    if (_orderId == null) {
      CustomToast.show(
        context,
        message: 'Ошибка: ID заказа не найден',
        isSuccess: false,
      );
      return;
    }

    if (_selectedDeliveryType == 'pickup' && _selectedCompanyId == null) {
      CustomToast.show(
        context,
        message: 'Пожалуйста, выберите адрес магазина',
        isSuccess: false,
      );
      return;
    }

    if (_selectedDeliveryType == 'delivery' && _address.isEmpty) {
      CustomToast.show(
        context,
        message: 'Пожалуйста, укажите адрес доставки',
        isSuccess: false,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? result;

      if (_selectedDeliveryType == 'pickup') {
        result = await OrderServices.updateOrderAddress(
          orderId: _orderId!,
          companyId: _selectedCompanyId,
        );
      } else {
        result = await OrderServices.updateOrderAddress(
          orderId: _orderId!,
          address: _address,
          latitude: _latitude ?? 0.0,
          longitude: _longitude ?? 0.0,
        );
      }

      if (result != null) {
        // Clear delivery flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notEnteredDelivery', false);

        if (mounted) {
          CustomToast.show(
            context,
            message: 'Адрес успешно сохранен!',
            isSuccess: true,
          );

          // Navigate back to home
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          ).then((_) {
            // Show info modal after navigation
            if (mounted) {
              _showAdminContactModal();
            }
          });
        }
      } else {
        if (mounted) {
          CustomToast.show(
            context,
            message: 'Ошибка при сохранении адреса',
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Ошибка: ${e.toString()}',
          isSuccess: false,
        );
      }
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
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];

    return PopScope(
      canPop: false, // Prevent back navigation
      onPopInvoked: (didPop) {
        if (didPop) {
          // This shouldn't happen, but just in case
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false, // Remove back button
          title: Text(
            'Адрес доставки',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery type selection dropdown
              Text(
                'Способ получения',
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16.h),
              // Select dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(
                    color: borderColor ?? Colors.grey,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    // Pickup option
                    RadioListTile<String>(
                      value: 'pickup',
                      groupValue: _selectedDeliveryType,
                      onChanged: (value) {
                        if (value != null) {
                          _selectPickup();
                        }
                      },
                      title: Text(
                        'Забрать из магазина',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      activeColor: const Color(0xFF1B7EFF),
                      contentPadding: EdgeInsets.zero,
                    ),
                    // Delivery option
                    RadioListTile<String>(
                      value: 'delivery',
                      groupValue: _selectedDeliveryType,
                      onChanged: (value) {
                        if (value != null) {
                          _selectDelivery();
                        }
                      },
                      title: Text(
                        'Доставка',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      activeColor: const Color(0xFF1B7EFF),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24.h),
              
              // Pickup: Office selection
              if (_selectedDeliveryType == 'pickup') ...[
                Text(
                  'Выберите офис',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 16.h),
                GestureDetector(
                  onTap: _showCompanyAddressesModal,
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border.all(
                        color: borderColor ?? Colors.grey,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: const Color(0xFF1B7EFF)),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _isLoadingAddresses
                              ? Text(
                                  'Загрузка адресов...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    color: subtitleColor,
                                  ),
                                )
                              : _selectedCompanyId != null
                                  ? Text(
                                      _companyAddresses
                                          .firstWhere(
                                            (a) => a['id'] == _selectedCompanyId,
                                            orElse: () => {'address': 'Адрес не выбран'},
                                          )['address']
                                          ?.toString() ??
                                          'Адрес не выбран',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        color: textColor,
                                      ),
                                    )
                                  : Text(
                                      'Выберите адрес',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        color: subtitleColor,
                                      ),
                                    ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: textColor.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Delivery: Address input and map button
              if (_selectedDeliveryType == 'delivery') ...[
                Text(
                  'Адрес доставки',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 16.h),
                // Address input for delivery
                TextField(
                    controller: _addressController,
                    onChanged: (value) {
                      setState(() {
                        _address = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Введите адрес доставки',
                      hintStyle: GoogleFonts.poppins(
                        color: textColor.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                          color: Color(0xFF1B7EFF),
                          width: 2,
                        ),
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      color: textColor,
                    ),
                    maxLines: 3,
                  ),
              ],
              
              SizedBox(height: 24.h),
              
              // Submit button
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B7EFF),
                      disabledBackgroundColor: const Color(0xFF1B7EFF).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
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
                            'Подтвердить',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
