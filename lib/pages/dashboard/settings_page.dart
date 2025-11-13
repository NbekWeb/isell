import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/theme_service.dart';
import 'company_addresses_page.dart';

class SettingsPage extends StatefulWidget {
  final Function(ThemeMode)? onThemeUpdate;
  
  const SettingsPage({super.key, this.onThemeUpdate});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _currentTheme = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeMode = await ThemeService.getThemeMode();
    setState(() {
      _currentTheme = themeMode;
    });
  }

  Future<void> _toggleTheme() async {
    final newTheme = await ThemeService.toggleTheme(_currentTheme);
    setState(() {
      _currentTheme = newTheme;
    });
    if (widget.onThemeUpdate != null) {
      widget.onThemeUpdate!(newTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use _currentTheme to determine if dark mode is active
    bool isDark;
    if (_currentTheme == ThemeMode.dark) {
      isDark = true;
    } else if (_currentTheme == ThemeMode.light) {
      isDark = false;
    } else {
      // System mode - use current theme brightness
      isDark = Theme.of(context).brightness == Brightness.dark;
    }
    final containerColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);
    final dividerColor = isDark ? (Colors.grey[800] ?? Colors.grey) : (Colors.grey[300] ?? Colors.grey);
    final iconBgColor = isDark ? const Color(0xFFF3F4F6) : (Colors.grey[200] ?? Colors.grey);
    final iconColor = isDark ? const Color(0xFF4B5563) : Colors.black87;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            // User Profile Header
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/svg/user.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF2563EB),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Пользователь',
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'user@example.com',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            // Settings Options - All in one container
            Container(
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: 'assets/svg/user.svg',
                    title: 'Профиль',
                    subtitle: 'Личные данные и настройки',
                    onTap: () {},
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    iconBgColor: iconBgColor,
                    iconColor: iconColor,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor,
                  ),
                  _buildSettingItem(
                    icon: 'assets/svg/ring.svg',
                    title: 'Уведомления',
                    subtitle: 'Настройки push-уведомлений',
                    onTap: () {},
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    iconBgColor: iconBgColor,
                    iconColor: iconColor,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor,
                  ),
                  _buildSettingItem(
                    icon: 'assets/svg/bez.svg',
                    title: 'Безопасность',
                    subtitle: 'Пароль и двухфакторная аутентификация',
                    onTap: () {},
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    iconBgColor: iconBgColor,
                    iconColor: iconColor,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor,
                  ),
                  _buildSettingItem(
                    icon: 'assets/svg/question.svg',
                    title: 'Помощь',
                    subtitle: 'FAQ и служба поддержки',
                    onTap: () {},
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    iconBgColor: iconBgColor,
                    iconColor: iconColor,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor,
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompanyAddressesPage(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: containerColor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/svg/doc.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  iconColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Адреса',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Адреса компании',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: subtitleColor,
                            size: 24.w,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            // Dark Theme Toggle
            GestureDetector(
              onTap: _toggleTheme,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Stack(
                  children: [
                    // Icon on the left
                    Positioned(
                      left: 16.w,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SvgPicture.asset(
                          isDark ? 'assets/svg/moon.svg' : 'assets/svg/moonl.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            textColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    // Text centered
                    Center(
                      child: Text(
                        _currentTheme == ThemeMode.dark ? 'Тёмной тема' : 'Светлая тема',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            // Logout Button
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Stack(
                children: [
                  // Icon on the left
                  Positioned(
                    left: 16.w,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/svg/logout.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.red,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  // Text centered
                  Center(
                    child: Text(
                      'Выйти',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtitleColor,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: SvgPicture.asset(
                  icon,
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: subtitleColor,
              size: 24.w,
            ),
          ],
        ),
      ),
    );
  }
}

