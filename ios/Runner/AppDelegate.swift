import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "simply_spectrum/platform"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "setWakelock":
          let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
          DispatchQueue.main.async {
            application.isIdleTimerDisabled = enabled
            result(nil)
          }
        case "getGalleryPath":
          // iOS Photo Library assets don't have a traditional file
          // path. Return a human-readable label for the SnackBar.
          result("Photos album \"SimplySpectrum\"")
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
