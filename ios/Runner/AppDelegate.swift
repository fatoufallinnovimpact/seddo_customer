import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import GoogleMaps
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

  private var activeActivityId: String?
  private var tokenEventSink: FlutterEventSink?
  private var pushToStartEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Initialisation Google Maps SDK
    GMSServices.provideAPIKey("AIzaSyAy0NF-94Jy_2pDVX8_X5vtvs3_RPH40wk")

    // Initialisation sécurisée de Firebase avec GoogleService-Info.plist
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let _ = NSDictionary(contentsOfFile: path) {
      FirebaseApp.configure()
    }

    // Configuration des notifications push et délégués
    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

    // Configuration des canaux Live Activities pour Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      setupLiveActivityChannels(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Flutter Method & Event Channels
  private func setupLiveActivityChannels(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "sn.innov.seddo/live_updates",
      binaryMessenger: messenger
    )

    methodChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleLiveUpdateMethodCall(call: call, result: result)
    }

    let tokenChannel = FlutterEventChannel(
      name: "sn.innov.seddo/live_updates_tokens",
      binaryMessenger: messenger
    )
    tokenChannel.setStreamHandler(TokenStreamHandler { [weak self] sink in
      self?.tokenEventSink = sink
    })

    let pushToStartChannel = FlutterEventChannel(
      name: "sn.innov.seddo/live_updates_push_to_start",
      binaryMessenger: messenger
    )
    pushToStartChannel.setStreamHandler(TokenStreamHandler { [weak self] sink in
      self?.pushToStartEventSink = sink
      self?.listenToPushToStartTokens()
    })
  }

  private func handleLiveUpdateMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    if #available(iOS 16.1, *) {
      switch call.method {
      case "isSupported":
        result(ActivityAuthorizationInfo().areActivitiesEnabled)

      case "areActivitiesEnabled":
        result(ActivityAuthorizationInfo().areActivitiesEnabled)

      case "startLiveUpdate":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments attendus", details: nil))
          return
        }
        startLiveActivity(args: args, result: result)

      case "updateLiveUpdate":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments attendus", details: nil))
          return
        }
        updateLiveActivity(args: args, result: result)

      case "endLiveUpdate":
        guard let args = call.arguments as? [String: Any] else {
          endAllLiveActivities()
          result(nil)
          return
        }
        endLiveActivity(args: args, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
      return
    }
    #endif

    // Fallback pour iOS < 16.1
    if call.method == "isSupported" || call.method == "areActivitiesEnabled" {
      result(false)
    } else {
      result(nil)
    }
  }

  #if canImport(ActivityKit)
  @available(iOS 16.1, *)
  private func startLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
    let rideId = args["rideId"] as? String ?? UUID().uuidString
    let driverName = args["driverName"] as? String ?? "Chauffeur"
    let carModel = args["carModel"] as? String ?? "Véhicule Seddo"
    let carColor = args["carColor"] as? String ?? "Gris"
    let licensePlate = args["licensePlate"] as? String ?? ""
    let departureText = args["departureText"] as? String ?? ""
    let destinationText = args["destinationText"] as? String ?? ""

    let status = args["phase"] as? String ?? "driverAssigned"
    let statusLabel = args["statusLabel"] as? String ?? "Chauffeur assigné"
    let etaMinutes = args["etaMinutes"] as? Int ?? 5
    let progress = args["progress"] as? Double ?? 0.15
    let timestamp = args["updatedAtTimestamp"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000)

    let attributes = RideActivityAttributes(
      rideId: rideId,
      driverName: driverName,
      carModel: carModel,
      carColor: carColor,
      licensePlate: licensePlate,
      departureText: departureText,
      destinationText: destinationText
    )

    let initialContentState = RideActivityAttributes.ContentState(
      status: status,
      statusLabel: statusLabel,
      etaMinutes: etaMinutes,
      progress: progress,
      updatedAtTimestamp: timestamp
    )

    do {
      let activity = try Activity<RideActivityAttributes>.request(
        attributes: attributes,
        contentState: initialContentState,
        pushType: .token
      )
      self.activeActivityId = activity.id

      // Écoute des mises à jour du jeton push APNs de cette activité
      Task {
        for await pushToken in activity.pushTokenUpdates {
          let tokenHex = pushToken.map { String(format: "%02x", $0) }.joined()
          print("[ActivityKit] 🔑 Jeton push de la Live Activity reçu: \(tokenHex)")
          DispatchQueue.main.async {
            self.tokenEventSink?(tokenHex)
          }
        }
      }

      result(activity.id)
    } catch {
      print("[ActivityKit] Erreur au démarrage de l'activité: \(error.localizedDescription)")
      result(FlutterError(code: "ACTIVITY_START_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  @available(iOS 16.1, *)
  private func updateLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
    let status = args["phase"] as? String ?? "inProgress"
    let statusLabel = args["statusLabel"] as? String ?? ""
    let etaMinutes = args["etaMinutes"] as? Int ?? 0
    let progress = args["progress"] as? Double ?? 0.5
    let timestamp = args["updatedAtTimestamp"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000)

    let updatedContentState = RideActivityAttributes.ContentState(
      status: status,
      statusLabel: statusLabel,
      etaMinutes: etaMinutes,
      progress: progress,
      updatedAtTimestamp: timestamp
    )

    Task {
      for activity in Activity<RideActivityAttributes>.activities {
        await activity.update(using: updatedContentState)
      }
      DispatchQueue.main.async {
        result(nil)
      }
    }
  }

  @available(iOS 16.1, *)
  private func endLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
    Task {
      for activity in Activity<RideActivityAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
      }
      DispatchQueue.main.async {
        result(nil)
      }
    }
  }

  @available(iOS 16.1, *)
  private func endAllLiveActivities() {
    Task {
      for activity in Activity<RideActivityAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
  }

  private func listenToPushToStartTokens() {
    if #available(iOS 17.2, *) {
      Task {
        for await tokenData in Activity<RideActivityAttributes>.pushToStartTokenUpdates {
          let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
          print("[ActivityKit] 🔑 Jeton Push-to-Start (iOS 17.2+) reçu: \(tokenHex)")
          DispatchQueue.main.async {
            self.pushToStartEventSink?(tokenHex)
          }
        }
      }
    }
  }
  #endif

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    print("[APNs] Token APNs reçu et transmis à Firebase")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[APNs] ERREUR: \(error.localizedDescription)")
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("[FCM] Token FCM reçu: \(fcmToken ?? "nil")")
  }
}

// MARK: - FlutterStreamHandler Helper
class TokenStreamHandler: NSObject, FlutterStreamHandler {
  private let onListenBlock: (FlutterEventSink?) -> Void

  init(onListen: @escaping (FlutterEventSink?) -> Void) {
    self.onListenBlock = onListen
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListenBlock(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onListenBlock(nil)
    return nil
  }
}
