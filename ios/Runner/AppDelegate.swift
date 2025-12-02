import Flutter
import UIKit
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Yandex MapKit
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "YANDEX_MAPKIT_API_KEY") as? String {
      YMKMapKit.setApiKey(apiKey)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Register MyID plugin manually
    // Get the FlutterViewController and create a registrar
    if let controller = window?.rootViewController as? FlutterViewController {
      let registrar = self.registrar(forPlugin: "MyIdPlugin")
      MyIdPlugin.register(with: registrar!)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
