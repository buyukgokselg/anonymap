import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let configChannel = FlutterMethodChannel(
      name: "pulsecity/runtime_config",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    configChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getRuntimeConfig" else {
        result(FlutterMethodNotImplemented)
        return
      }

      result([
        "googlePlacesApiKey": self?.stringConfig(for: "GooglePlacesApiKey") ?? "",
        "mapboxAccessToken": self?.stringConfig(for: "MBXAccessToken") ?? "",
        "backendBaseUrl": self?.stringConfig(for: "BackendBaseUrl") ?? "",
      ])
    }
  }

  private func stringConfig(for key: String) -> String {
    Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
  }
}
