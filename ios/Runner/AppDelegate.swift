import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

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
