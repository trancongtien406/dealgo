import CallKit
import Flutter
import PushKit
import UIKit
import UserNotifications
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate {
  private var voipRegistry: PKPushRegistry?
  /// Last-resort CallKit reporter when the plugin is not attached yet.
  private lazy var fallbackProvider = CXProvider(configuration: CXProviderConfiguration())
  /// Same key flutter_callkit_incoming reads in getDevicePushTokenVoIP().
  private static let voipTokenDefaultsKey = "DevicePushTokenVoIP"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase.initializeApp is owned by Dart. Request APNs so FCM can map a
    // device token; FlutterAppDelegate + firebase_messaging method swizzling
    // forwards the token into Messaging (FirebaseMessaging is not a direct
    // Runner SPM product under FlutterGeneratedPluginSwiftPackage).
    application.registerForRemoteNotifications()
    // own the notification-center delegate (FlutterAppDelegate forwards to
    // plugins, firebase_messaging included) so a call push can skip the banner.
    UNUserNotificationCenter.current().delegate = self
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // VoIP (PushKit) registration for incoming calls. Created after super so
    // the implicit engine has registered flutter_callkit_incoming first. The
    // backend only sends VoIP pushes when APNS_KEY_ID / APNS_TEAM_ID /
    // APNS_KEY_PATH are set; without them calls ring via the FCM alert.
    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
    return launched
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
  ) {
    // Keep FlutterAppDelegate as UNUserNotificationCenter / APNs owner so the
    // firebase_messaging plugin receives the token via swizzling.
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Call dedupe: with the app open, an incoming call already rings on the
  // in-app call screen (socket) and/or CallKit (PushKit). The FCM "đang gọi"
  // banner + sound would be a second ring, so it is not presented. Every other
  // push keeps the normal path (firebase_messaging presentation options).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let event = notification.request.content.userInfo["eventType"] as? String
    if event == "Call.incoming" {
      completionHandler([])
      return
    }
    super.userNotificationCenter(
      center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: PushKit

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    // Dart reads it via FlutterCallkitIncoming.getDevicePushTokenVoIP() and
    // registers it with the backend as platform "ios-voip".
    storeVoipToken(token)
  }

  /// Hands the token to the plugin (which emits the Dart "token updated"
  /// event so it is uploaded again); before the plugin attaches it is kept
  /// where getDevicePushTokenVoIP() reads it.
  private func storeVoipToken(_ token: String) {
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      plugin.setDevicePushTokenVoIP(token)
    } else {
      UserDefaults.standard.set(token, forKey: AppDelegate.voipTokenDefaultsKey)
    }
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    storeVoipToken("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }
    // iOS 13+ terminates the app unless every VoIP push reports a call to
    // CallKit, so always show one (even for a malformed payload).
    let dict = payload.dictionaryPayload
    let callId = (dict["callId"] as? String) ?? UUID().uuidString
    // The backend sends data values as strings (FCM-compatible map).
    let ringSeconds = (dict["ringSeconds"] as? Int)
      ?? (dict["ringSeconds"] as? String).flatMap { Int($0) }
      ?? 40
    var extra: [String: Any] = [:]
    for (key, value) in dict {
      guard let key = key as? String, key != "aps" else { continue }
      extra[key] = "\(value)"
    }

    var info = [String: Any?]()
    info["id"] = callId
    info["nameCaller"] = (dict["title"] as? String) ?? "Cuộc gọi DealGo"
    info["appName"] = "DealGo"
    info["handle"] = (dict["body"] as? String) ?? ""
    info["type"] = 0
    info["duration"] = ringSeconds * 1000
    info["extra"] = extra
    info["missedCallNotification"] = ["showNotification": false]
    info["callingNotification"] = [
      "showNotification": true,
      "subtitle": "Đang gọi…",
      "callbackText": "Kết thúc",
    ]
    info["ios"] = [
      "handleType": "generic",
      "supportsVideo": false,
      "maximumCallGroups": 1,
      "maximumCallsPerCallGroup": 1,
      "audioSessionMode": "voiceChat",
      "audioSessionActive": true,
      "supportsDTMF": false,
      "supportsHolding": false,
      "supportsGrouping": false,
      "supportsUngrouping": false,
      "ringtonePath": "system_ringtone_default",
    ]

    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      // Still satisfy the PushKit contract: report, then end the call at once
      // (the caller falls back to the in-app ring / missed-call push).
      let uuid = UUID(uuidString: callId) ?? UUID()
      let update = CXCallUpdate()
      update.remoteHandle = CXHandle(type: .generic, value: "DealGo")
      update.localizedCallerName = (dict["title"] as? String) ?? "Cuộc gọi DealGo"
      fallbackProvider.reportNewIncomingCall(with: uuid, update: update) { _ in
        self.fallbackProvider.reportCall(with: uuid, endedAt: nil, reason: .failed)
        completion()
      }
      return
    }
    plugin.showCallkitIncoming(
      flutter_callkit_incoming.Data(args: info),
      fromPushKit: true,
      completion: completion
    )
  }
}
