import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../widgets/custom_toast.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Load cached data first
      final cachedData = await UserService.getCachedUserData();
      if (cachedData != null) {
        setState(() {
          _userData = cachedData;
          _isLoading = false;
        });
      }

      // Fetch fresh data
      final result = await UserService.getCurrentUser();
      if (result != null && result['success'] == true) {
        setState(() {
          _userData = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUserData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadUserData();
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return 'Не указан';
    
    // Format: 998770580502 -> +998 77 058 05 02
    if (phone.length >= 12 && phone.startsWith('998')) {
      return '+${phone.substring(0, 3)} ${phone.substring(3, 5)} ${phone.substring(5, 8)} ${phone.substring(8, 10)} ${phone.substring(10)}';
    }
    return '+$phone';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Не указана';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final containerColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
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
        title: Text(
          'Профиль',
          style: GoogleFonts.poppins(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: textColor,
            ),
            onPressed: _refreshUserData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.blue[400] : Colors.blue,
              ),
            )
          : _userData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64.sp,
                        color: subtitleColor,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Не удалось загрузить данные профиля',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          color: subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: _refreshUserData,
                        child: Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        // Profile Header
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24.w),
                          decoration: BoxDecoration(
                            color: containerColor,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Avatar
                              Container(
                                width: 100.w,
                                height: 100.w,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF374151) : const Color(0xFFDBEAFE),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: _userData!['avatar'] != null
                                      ? ClipOval(
                                          child: Image.network(
                                            _userData!['avatar'],
                                            width: 100.w,
                                            height: 100.w,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : SvgPicture.asset(
                                          'assets/svg/user.svg',
                                          width: 40.w,
                                          height: 40.w,
                                          colorFilter: ColorFilter.mode(
                                            isDark ? const Color(0xFF9CA3AF) : const Color(0xFF2563EB),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(height: 16.h),
                              
                              // Name
                              Text(
                                '${_userData!['first_name'] ?? ''} ${_userData!['last_name'] ?? ''}'.trim(),
                                style: GoogleFonts.poppins(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8.h),
                              
                              // Phone
                              Text(
                                _formatPhoneNumber(_userData!['phone_number']?.toString()),
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
                                  color: subtitleColor,
                                ),
                              ),
                              
                              // MyID Verification Status
                              if (_userData!['is_veriifed_my_id'] == true) ...[
                                SizedBox(height: 12.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        size: 16.sp,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'MyID верифицирован',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 24.h),
                        
                        // Personal Information
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: containerColor,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Личная информация',
                                style: GoogleFonts.poppins(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 20.h),
                              
                              _buildInfoRow('Дата рождения', _formatDate(_userData!['date_of_birth']?.toString()), textColor, subtitleColor),
                              _buildInfoRow('ПИНФЛ', _userData!['pnfl']?.toString() ?? 'Не указан', textColor, subtitleColor),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 24.h),
                        
                        // Address Information
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: containerColor,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Адрес',
                                style: GoogleFonts.poppins(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 20.h),
                              
                              _buildInfoRow('Страна', _userData!['country']?.toString() ?? 'Не указана', textColor, subtitleColor),
                              _buildInfoRow('Регион', _userData!['region']?.toString() ?? 'Не указан', textColor, subtitleColor),
                              _buildInfoRow('Город', _userData!['city']?.toString() ?? 'Не указан', textColor, subtitleColor),
                              _buildInfoRow('Улица', _userData!['street']?.toString() ?? 'Не указана', textColor, subtitleColor),
                              _buildInfoRow('Дом', _userData!['house']?.toString() ?? 'Не указан', textColor, subtitleColor),
                              if (_userData!['apartment']?.toString().isNotEmpty == true)
                                _buildInfoRow('Квартира', _userData!['apartment'].toString(), textColor, subtitleColor),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textColor, Color? subtitleColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
