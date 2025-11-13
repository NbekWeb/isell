import Flutter
import UIKit
import YandexMapsMobile
import MyIdSDK

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
    
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.isell.myid/sdk",
        binaryMessenger: controller.binaryMessenger
      )
      myIdCoordinator = MyIdSdkCoordinator(controller: controller, channel: channel)
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "startMyId" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.myIdCoordinator?.start(arguments: call.arguments, flutterResult: result)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private var myIdCoordinator: MyIdSdkCoordinator?
}

private class MyIdSdkCoordinator: NSObject, MyIdClientDelegate {
  private weak var controller: FlutterViewController?
  private var pendingResult: FlutterResult?
  private let channel: FlutterMethodChannel
  
  init(controller: FlutterViewController, channel: FlutterMethodChannel) {
    self.controller = controller
    self.channel = channel
  }
  
  func start(arguments: Any?, flutterResult: @escaping FlutterResult) {
    guard pendingResult == nil else {
      flutterResult(
        FlutterError(
          code: "myid_in_progress",
          message: "MyID flow is already running",
          details: nil
        )
      )
      return
    }
    
    guard let controller = controller else {
      flutterResult(
        FlutterError(
          code: "controller_unavailable",
          message: "Flutter controller is not available",
          details: nil
        )
      )
      return
    }
    
    guard let args = arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String,
          let clientHash = args["clientHash"] as? String,
          let clientHashId = args["clientHashId"] as? String else {
      flutterResult(
        FlutterError(
          code: "invalid_arguments",
          message: "sessionId, clientHash and clientHashId are required",
          details: nil
        )
      )
      return
    }
    
    let config = MyIdConfig()
    config.sessionId = sessionId
    config.clientHash = clientHash
    config.clientHashId = clientHashId
    
    if let minAge = args["minAge"] as? Int {
      config.minAge = minAge
    }
    
    if let locale = args["locale"] as? String {
      config.locale = mapLocale(from: locale)
    }
    
    if let environment = args["environment"] as? String {
      config.environment = mapEnvironment(from: environment)
    }
    
    if let entryType = args["entryType"] as? String {
      config.entryType = mapEntryType(from: entryType)
    }
    
    if let residency = args["residency"] as? String {
      config.residency = mapResidency(from: residency)
    }
    
    if let cameraShape = args["cameraShape"] as? String {
      config.cameraShape = mapCameraShape(from: cameraShape)
    }
    
    if let showErrorScreen = args["showErrorScreen"] as? Bool {
      config.showErrorScreen = showErrorScreen
    }
    
    if let organizationArgs = args["organizationDetails"] as? [String: Any] {
      config.organizationDetails = buildOrganizationDetails(from: organizationArgs, controller: controller)
    }
    
    if let appearanceArgs = args["appearance"] as? [String: Any] {
      config.appearance = buildAppearance(from: appearanceArgs)
    }
    
    pendingResult = flutterResult
    DispatchQueue.main.async {
      MyIdClient.start(withConfig: config, withDelegate: self)
    }
  }
  
  func onSuccess(result: MyIdResult) {
    var payload: [String: Any] = ["status": "success"]
    if let code = extractValue(forKey: "code", from: result) as? String {
      payload["code"] = code
    }
    if let reuid = extractValue(forKey: "reuid", from: result) as? String {
      payload["reuid"] = reuid
    }
    if let comparison = extractValue(forKey: "comparisonValue", from: result) {
      payload["comparisonValue"] = comparison
    }
    if let image = extractValue(forKey: "image", from: result) as? UIImage,
       let data = image.jpegData(compressionQuality: 0.9) {
      payload["imageBase64"] = data.base64EncodedString()
    }
    finish(payload)
  }
  
  func onError(exception: MyIdException) {
    var payload: [String: Any] = [
      "status": "error"
    ]
    if let code = extractValue(forKey: "code", from: exception) {
      payload["code"] = code
    }
    if let message = extractValue(forKey: "message", from: exception) {
      payload["message"] = message
    }
    finish(payload)
  }
  
  func onUserExited() {
    let payload: [String: Any] = ["status": "cancelled"]
    finish(payload)
  }
  
  func onEvent(event: MyIdEvent) {
    var payload: [String: Any] = [
      "type": "event",
      "event": event.rawValue
    ]
    
    if let additional = extractValue(forKey: "additionalInfo", from: event) {
      payload["additionalInfo"] = additional
    }
    
    channel.invokeMethod("myIdEvent", arguments: payload)
  }
  
  private func finish(_ payload: [String: Any]) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    result(payload)
  }
  
  private func extractValue(forKey key: String, from object: Any) -> Any? {
    let mirror = Mirror(reflecting: object)
    for child in mirror.children {
      if child.label == key {
        return child.value
      }
    }
    
    if let nsObject = object as? NSObject {
      return nsObject.value(forKey: key)
    }
    
    return nil
  }
  
  private func mapLocale(from value: String) -> MyIdLocale {
    switch value.lowercased() {
    case "en", "english":
      return .EN
    case "ru", "russian":
      return .RU
    default:
      return .UZ
    }
  }
  
  private func mapEnvironment(from value: String) -> MyIdEnvironment {
    switch value.lowercased() {
    case "debug", "sandbox":
      return .debug
    default:
      return .production
    }
  }
  
  private func mapEntryType(from value: String) -> MyIdEntryType {
    switch value.lowercased() {
    case "facedetection", "face_detection":
      return .faceDetection
    default:
      return .identification
    }
  }
  
  private func mapResidency(from value: String) -> MyIdResidency {
    switch value.lowercased() {
    case "nonresident", "non_resident":
      return .nonResident
    case "userdefined", "user_defined":
      return .userDefined
    default:
      return .resident
    }
  }
  
  private func mapCameraShape(from value: String) -> MyIdCameraShape {
    switch value.lowercased() {
    case "ellipse":
      return .ellipse
    default:
      return .circle
    }
  }
  
  private func buildOrganizationDetails(from dict: [String: Any], controller: FlutterViewController) -> MyIdOrganizationDetails {
    let details = MyIdOrganizationDetails()
    if let phone = dict["phoneNumber"] as? String {
      details.phoneNumber = phone
    }
    if let base64 = dict["logoBase64"] as? String,
       let data = Data(base64Encoded: base64),
       let image = UIImage(data: data) {
      details.logo = image
    } else if let asset = dict["logoAsset"] as? String,
              let image = loadImage(fromAsset: asset, controller: controller) {
      details.logo = image
    }
    return details
  }
  
  private func buildAppearance(from dict: [String: Any]) -> MyIdAppearance {
    let appearance = MyIdAppearance()
    appearance.colorPrimary = color(from: dict["colorPrimary"])
    appearance.colorOnPrimary = color(from: dict["colorOnPrimary"])
    appearance.colorError = color(from: dict["colorError"])
    appearance.colorOnError = color(from: dict["colorOnError"])
    appearance.colorOutline = color(from: dict["colorOutline"])
    appearance.colorDivider = color(from: dict["colorDivider"])
    appearance.colorSuccess = color(from: dict["colorSuccess"])
    appearance.colorButtonContainer = color(from: dict["colorButtonContainer"])
    appearance.colorButtonContainerDisabled = color(from: dict["colorButtonContainerDisabled"])
    appearance.colorButtonContent = color(from: dict["colorButtonContent"])
    appearance.colorButtonContentDisabled = color(from: dict["colorButtonContentDisabled"])
    if let radius = dict["buttonCornerRadius"] as? NSNumber {
      appearance.buttonCornerRadius = CGFloat(truncating: radius)
    } else if let radius = dict["buttonCornerRadius"] as? Double {
      appearance.buttonCornerRadius = CGFloat(radius)
    }
    return appearance
  }
  
  private func color(from value: Any?) -> UIColor? {
    guard let string = value as? String else { return nil }
    return UIColor(hex: string)
  }
  
  private func loadImage(fromAsset asset: String, controller: FlutterViewController) -> UIImage? {
    let key = FlutterDartProject.lookupKey(forAsset: asset, fromPackage: nil)
    if let path = Bundle.main.path(forResource: key, ofType: nil, inDirectory: "flutter_assets") {
      return UIImage(contentsOfFile: path)
    }
    return nil
  }
}

private extension UIColor {
  convenience init?(hex: String) {
    var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if sanitized.hasPrefix("#") {
      sanitized.removeFirst()
    }
    
    guard sanitized.count == 6 || sanitized.count == 8,
          let hexNumber = UInt64(sanitized, radix: 16) else {
      return nil
    }
    
    let r, g, b, a: CGFloat
    if sanitized.count == 8 {
      r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
      g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
      b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
      a = CGFloat(hexNumber & 0x000000FF) / 255.0
    } else {
      r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
      g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
      b = CGFloat(hexNumber & 0x0000FF) / 255.0
      a = 1.0
    }
    
    self.init(red: r, green: g, blue: b, alpha: a)
  }
}
