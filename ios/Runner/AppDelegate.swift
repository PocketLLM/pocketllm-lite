import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let storageChannel = FlutterMethodChannel(name: "pocketllm_lite/storage",
                                              binaryMessenger: controller.binaryMessenger)
    storageChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getFreeDiskSpace" {
        do {
          let fileURL = URL(fileURLWithPath: NSHomeDirectory())
          let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
          if let capacity = values.volumeAvailableCapacityForImportantUsage {
            result(capacity)
          } else {
            // Fallback
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = systemAttributes[.systemFreeSize] as? Int64 {
              result(freeSpace)
            } else {
              result(FlutterError(code: "STORAGE_ERROR", message: "Unable to retrieve storage capacity", details: nil))
            }
          }
        } catch {
          result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
