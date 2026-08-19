import Flutter
import UIKit
import PushKit
import CallKit
import AVFoundation
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate, FlutterImplicitEngineDelegate {
  private func resolvedUuid(from payload: [String: Any]) -> String {
    let candidates = [
      payload["uuid"],
      payload["id"],
      payload["call_id"],
      payload["callId"],
    ]

    for candidate in candidates {
      if let value = candidate as? String,
         !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
         UUID(uuidString: value) != nil {
        return value
      }
    }

    return UUID().uuidString
  }

  private func normalizedCallkitPayload(from payload: [String: Any]) -> [String: Any] {
    let uuid = resolvedUuid(from: payload)
    let callerName =
      (payload["nameCaller"] as? String) ??
      (payload["caller_name"] as? String) ??
      (payload["callerName"] as? String) ??
      "Cuộc gọi đến"

    var normalized = payload
    normalized["uuid"] = uuid
    normalized["id"] = uuid
    normalized["nameCaller"] = callerName
    normalized["handle"] = (payload["handle"] as? String) ?? callerName
    normalized["iconName"] = (payload["iconName"] as? String) ?? "AppIcon"
    normalized["textAccept"] = (payload["textAccept"] as? String) ?? "Chấp nhận"
    normalized["textDecline"] = (payload["textDecline"] as? String) ?? "Từ chối"
    normalized["ringtonePath"] = (payload["ringtonePath"] as? String) ?? "ringtone.mp3"

    if normalized["extra"] == nil {
      normalized["extra"] = [
        "callId": (payload["call_id"] as? String) ?? (payload["callId"] as? String) ?? uuid,
        "callDirection": "incoming",
      ]
    }

    return normalized
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Setup VoIP Registry
    let mainQueue = DispatchQueue.main
    let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Handle Push Credentials (save this token to your server)
  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
    print("VoIP Device Token: \(deviceToken)")
  }

  // Handle Incoming VoIP Payload
  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    if type == .voIP {
      // Extract data from payload and show call using the plugin
      if let dataDict = payload.dictionaryPayload as? [String: Any] {
        let normalizedPayload = normalizedCallkitPayload(from: dataDict)
        let data = flutter_callkit_incoming.Data(args: normalizedPayload)
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
      }
    }
    completion()
  }

  // MARK: - CallkitIncomingAppDelegate Methods
  func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
    NSLog("onRunner :: Accept")
    action.fulfill()
  }

  func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    NSLog("onRunner :: Decline")
    action.fulfill()
  }

  func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    NSLog("onRunner :: onEnd")
    action.fulfill()
  }

  func onTimeOut(_ call: flutter_callkit_incoming.Call) {
    NSLog("onRunner :: TimeOut")
  }

  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    NSLog("onRunner :: didActivateAudioSession")
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    NSLog("onRunner :: didDeactivateAudioSession")
  }
}
