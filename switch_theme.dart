import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart switch_theme.dart [1|2]');
    print('1: Dark with blue accent');
    print('2: Dark with gradient');
    exit(1);
  }
  
  final theme = args[0];
  String configFile;
  
  switch (theme) {
    case '1':
      configFile = 'assets/splash/splash_theme1.yaml';
      print('🎨 Switching to Theme 1: Dark with blue accent');
      break;
    case '2':
      configFile = 'assets/splash/splash_theme2.yaml';
      print('🎨 Switching to Theme 2: Dark with gradient');
      break;
    default:
      print('❌ Invalid theme. Use 1 or 2');
      exit(1);
  }
  
  print('📱 Generating splash screen...');
  await Process.run('dart', ['run', 'flutter_native_splash:create', '--path=$configFile']);
  
  print('✅ Theme switched successfully!');
  print('💡 Run: flutter run to see the changes');
}
