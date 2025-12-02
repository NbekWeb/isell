import Flutter
import UIKit
import MyIdSDK
import AVFoundation

class MyIdPlugin: NSObject, FlutterPlugin, MyIdClientDelegate {
    static var shared: MyIdPlugin?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.isell.myid", binaryMessenger: registrar.messenger())
        let instance = MyIdPlugin()
        shared = instance
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    static func registerChannel(_ channel: FlutterMethodChannel) {
        let instance = MyIdPlugin()
        shared = instance
        channel.setMethodCallHandler(instance.handle)
    }
    
    private var result: FlutterResult?
    private var pendingCall: FlutterMethodCall?
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "startMyId" {
            self.result = result
            startMyId(call: call)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startMyId(call: FlutterMethodCall) {
        print("🔵 MyID Plugin - Received startMyId call")
        print("📥 Arguments: \(call.arguments ?? "nil")")
        
        // Check camera permission first
        var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 MyID Plugin - Camera permission status: \(cameraStatus.rawValue)")
        
        // If permission is not determined, wait a bit and check again
        // This handles the case where Flutter just requested permission but iOS hasn't updated the status yet
        if cameraStatus == .notDetermined {
            print("📷 MyID Plugin - Camera permission not determined, waiting 300ms and re-checking...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                print("📷 MyID Plugin - Camera permission status after wait: \(cameraStatus.rawValue)")
                
                if cameraStatus == .authorized {
                    print("✅ MyID Plugin - Camera permission granted (after wait)")
                    self?.startMyIdInternal(call: call)
                } else if cameraStatus == .denied || cameraStatus == .restricted {
                    print("❌ MyID Plugin - Camera permission denied or restricted")
                    self?.result?([
                        "success": false,
                        "code": "CAMERA_PERMISSION_DENIED",
                        "message": "Для работы MyID требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения."
                    ])
                    self?.result = nil
                } else {
                    // Still not determined - Flutter should have requested it, but let MyID SDK handle it
                    print("⚠️ MyID Plugin - Camera permission still not determined, letting MyID SDK handle it")
                    self?.startMyIdInternal(call: call)
                }
            }
            return
        } else if cameraStatus == .denied || cameraStatus == .restricted {
            print("❌ MyID Plugin - Camera permission denied or restricted")
            result?([
                "success": false,
                "code": "CAMERA_PERMISSION_DENIED",
                "message": "Для работы MyID требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения."
            ])
            result = nil
            return
        }
        
        // Permission is granted, proceed with starting MyID
        print("✅ MyID Plugin - Camera permission already granted")
        startMyIdInternal(call: call)
    }
    
    private func startMyIdInternal(call: FlutterMethodCall) {
        print("🔵 MyID Plugin - Starting MyID SDK (internal)")
        print("📥 Arguments: \(call.arguments ?? "nil")")
        
        guard let args = call.arguments as? [String: Any] else {
            print("❌ MyID Plugin - Invalid arguments")
            result?([
                "success": false,
                "code": "INVALID_ARGUMENTS",
                "message": "Invalid arguments"
            ])
            result = nil
            return
        }
        
        guard let sessionId = args["sessionId"] as? String,
              let clientHash = args["clientHash"] as? String,
              let clientHashId = args["clientHashId"] as? String else {
            print("❌ MyID Plugin - Missing required parameters")
            print("   - sessionId: \(args["sessionId"] ?? "nil")")
            print("   - clientHash: \(args["clientHash"] != nil ? "present" : "nil")")
            print("   - clientHashId: \(args["clientHashId"] ?? "nil")")
            result?([
                "success": false,
                "code": "MISSING_REQUIRED_PARAMS",
                "message": "sessionId, clientHash, and clientHashId are required"
            ])
            result = nil
            return
        }
        
        print("✅ MyID Plugin - Parameters received:")
        print("   - sessionId: \(sessionId)")
        print("   - clientHashId: \(clientHashId)")
        print("   - clientHash: \(String(clientHash.prefix(50)))...")
        
        let config = MyIdConfig()
        config.sessionId = sessionId
        config.clientHash = clientHash
        config.clientHashId = clientHashId
        
        // Environment
        if let environment = args["environment"] as? String {
            config.environment = environment == "debug" ? .debug : .production
        } else {
            config.environment = .production
        }
        
        // Entry type
        if let entryType = args["entryType"] as? String {
            config.entryType = entryType == "faceDetection" ? .faceDetection : .identification
        } else {
            config.entryType = .identification
        }
        
        // Min age
        if let minAge = args["minAge"] as? Int {
            config.minAge = minAge
        } else {
            config.minAge = 16
        }
        
        // Residency
        if let residency = args["residency"] as? String {
            switch residency {
            case "nonResident":
                config.residency = .nonResident
            case "userDefined":
                config.residency = .userDefined
            default:
                config.residency = .resident
            }
        } else {
            config.residency = .resident
        }
        
        // Locale
        if let locale = args["locale"] as? String {
            switch locale {
            case "russian":
                config.locale = .russian
            case "english":
                config.locale = .english
            default:
                config.locale = .uzbek
            }
        } else {
            config.locale = .uzbek
        }
        
        // Camera shape
        if let cameraShape = args["cameraShape"] as? String {
            config.cameraShape = cameraShape == "ellipse" ? .ellipse : .circle
        } else {
            config.cameraShape = .circle
        }
        
        // Show error screen
        if let showErrorScreen = args["showErrorScreen"] as? Bool {
            config.showErrorScreen = showErrorScreen
        } else {
            config.showErrorScreen = true
        }
        
        // Start MyID (it will present on the current top view controller)
        print("🔵 MyID Plugin - Starting MyID SDK with config:")
        print("   - sessionId: \(config.sessionId ?? "nil")")
        print("   - clientHashId: \(config.clientHashId ?? "nil")")
        print("   - environment: \(config.environment == .debug ? "debug" : "production")")
        print("   - entryType: \(config.entryType == .faceDetection ? "faceDetection" : "identification")")
        print("   - locale: \(config.locale == .russian ? "russian" : config.locale == .english ? "english" : "uzbek")")
        
        MyIdClient.start(withConfig: config, withDelegate: self)
    }
    
    // MARK: - MyIdClientDelegate
    
    func onSuccess(result: MyIdResult) {
        print("✅ MyID Plugin - onSuccess called")
        print("   - code: \(result.code ?? "nil")")
        print("   - image: \(result.image != nil ? "present" : "nil")")
        
        var response: [String: Any] = [
            "success": true
        ]
        
        // Add code - based on compiler error, result.code is String (non-optional)
        // So we can access it directly
        response["code"] = result.code
        
        // Add image if available
        if let image = result.image {
            // Convert UIImage to base64 string
            if let imageData = image.pngData() {
                let base64String = imageData.base64EncodedString()
                response["image"] = base64String
                print("   - image converted to base64: \(base64String.prefix(50))...")
            }
        }
        
        print("📤 MyID Plugin - Sending success response: \(response)")
        self.result?(response)
        self.result = nil
    }
    
    func onError(exception: MyIdException) {
        print("❌ MyID Plugin - onError called")
        print("   - code: \(exception.code)")
        print("   - message: \(exception.message)")
        
        let errorResponse: [String: Any] = [
            "success": false,
            "code": String(exception.code),
            "message": exception.message
        ]
        print("📤 MyID Plugin - Sending error response: \(errorResponse)")
        self.result?(errorResponse)
        self.result = nil
    }
    
    func onUserExited() {
        print("⚠️ MyID Plugin - onUserExited called")
        let exitResponse: [String: Any] = [
            "success": false,
            "code": "USER_EXITED",
            "message": "User exited the MyID flow"
        ]
        print("📤 MyID Plugin - Sending exit response: \(exitResponse)")
        self.result?(exitResponse)
        self.result = nil
    }
    
    func onEvent(event: MyIdEvent) {
        // Handle events if needed
        print("📢 MyID Plugin - Event: \(event.rawValue)")
    }
}
