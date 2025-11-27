import 'dart:io';

void main() async {

  // Generate Theme 1 (Dark with blue accent)

  await Process.run('flutter', ['packages', 'get']);
  await Process.run('dart', [
    'run',
    'flutter_native_splash:create',
    '--path=assets/splash/splash_theme1.yaml',
  ]);

  await Process.run('dart', [
    'run',
    'flutter_native_splash:create',
    '--path=assets/splash/splash_theme2.yaml',
  ]);
}
