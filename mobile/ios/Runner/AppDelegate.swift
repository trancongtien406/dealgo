import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase.initializeApp is owned by Dart. Request APNs so FCM can map a
    // device token; FlutterAppDelegate + firebase_messaging method swizzling
    // forwards the token into Messaging (FirebaseMessaging is not a direct
    // Runner SPM product under FlutterGeneratedPluginSwiftPackage).
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Keep FlutterAppDelegate as UNUserNotificationCenter / APNs owner so the
    // firebase_messaging plugin receives the token via swizzling.
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
