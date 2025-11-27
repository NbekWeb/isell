import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    exit(1);
  }
  
  final theme = args[0];
  String configFile;
  
  switch (theme) {
    case '1':
      configFile = 'assets/splash/splash_theme1.yaml';
      break;
    case '2':
      configFile = 'assets/splash/splash_theme2.yaml';
      break;
    default:
      exit(1);
  }
  
  await Process.run('dart', ['run', 'flutter_native_splash:create', '--path=$configFile']);
  
}
