import 'dart:io';

void main() async {
  print('🎨 Generating splash screens...');
  
  // Generate Theme 1 (Dark with blue accent)
  print('📱 Generating Theme 1: Dark with blue accent');
  await Process.run('flutter', ['packages', 'get']);
  await Process.run('dart', ['run', 'flutter_native_splash:create', '--path=assets/splash/splash_theme1.yaml']);
  
  print('✅ Theme 1 splash screen generated!');
  
  // Generate Theme 2 (Dark with gradient)
  print('📱 Generating Theme 2: Dark with gradient');
  await Process.run('dart', ['run', 'flutter_native_splash:create', '--path=assets/splash/splash_theme2.yaml']);
  
  print('✅ Theme 2 splash screen generated!');
  
  print('🎉 All splash screens generated successfully!');
  print('💡 You can now run: flutter run');
}
