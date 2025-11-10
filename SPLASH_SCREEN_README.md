# ISell Splash Screen - Dark Themes

Bu loyihada ikkita xil qora splash screen mavjud:

## 🎨 Mavzular

### 1. Theme 1: Dark with Blue Accent
- **Rang**: `#1a1a1a` (qora)
- **Xususiyat**: Oddiy qora fon, ko'k rangli aksent
- **Fayl**: `assets/splash/splash_theme1.yaml`

### 2. Theme 2: Dark with Gradient
- **Rang**: `#0d1117` (qora gradient)
- **Xususiyat**: Gradient fon, ko'k rangli glow effekt
- **Fayl**: `assets/splash/splash_theme2.yaml`

## 🚀 Foydalanish

### Dasturni ishga tushirish
```bash
flutter pub get
flutter run
```

### Splash screen mavzularini o'zgartirish

#### 1. Avtomatik o'zgarish
Dastur ishga tushganda splash screen avtomatik ravishda mavzular o'rtasida almashadi.

#### 2. Qo'lda o'zgartirish
```bash
# Theme 1 ni tanlash
dart switch_theme.dart 1

# Theme 2 ni tanlash  
dart switch_theme.dart 2
```

### Barcha splash screenlarni yaratish
```bash
dart generate_splash.dart
```

## 📱 Platformalar

- ✅ Android
- ✅ iOS
- ✅ Android 12+ (Splash Screen API)

## 🎯 Xususiyatlar

- **Animatsiya**: Fade va scale animatsiyalar
- **Logo**: ISell logosi markazda
- **Loading**: Circular progress indicator
- **Theme switching**: Avtomatik mavzu almashish
- **Persistence**: Tanlangan mavzu saqlanadi

## 📁 Fayl tuzilishi

```
assets/splash/
├── flutter_native_splash.yaml    # Asosiy konfiguratsiya
├── splash_theme1.yaml           # Theme 1 konfiguratsiyasi
└── splash_theme2.yaml           # Theme 2 konfiguratsiyasi

lib/screens/
└── splash_screen.dart           # Splash screen widget

generate_splash.dart             # Barcha splash screenlarni yaratish
switch_theme.dart               # Mavzuni o'zgartirish
```

## 🔧 Sozlash

Agar o'z ranglaringizni ishlatmoqchi bo'lsangiz, quyidagi fayllarni tahrirlang:

1. `assets/splash/splash_theme1.yaml` - Theme 1 ranglari
2. `assets/splash/splash_theme2.yaml` - Theme 2 ranglari
3. `lib/screens/splash_screen.dart` - Widget ranglari

## 🎨 Ranglar

### Theme 1
- Background: `#1a1a1a`
- Text: White
- Accent: Blue

### Theme 2  
- Background: `#0d1117` (gradient)
- Text: Blue[300]
- Accent: Blue with glow effect
