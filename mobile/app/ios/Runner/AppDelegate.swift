import Flutter
import UIKit
import UserNotifications
import workmanager_apple  // WorkManager plugin for iOS background tasks

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Key for storing pending notification payload in UserDefaults
  // Must include "flutter." prefix to match SharedPreferences on iOS
  private let pendingNotificationKey = "flutter.pending_cocktail_navigation"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Set ourselves as the notification center delegate BEFORE plugin registration
    // This ensures we can capture notification taps even on cold start
    UNUserNotificationCenter.current().delegate = self

    // Register all Flutter plugins FIRST
    GeneratedPluginRegistrant.register(with: self)

    // CRITICAL: Register WorkManager periodic task for token refresh AFTER plugins are registered
    // This enables iOS BGTaskScheduler to run our Dart background code
    // Frequency: 4 hours (14400 seconds) - iOS may adjust this based on user patterns
    // This addresses the Entra External ID 12-hour refresh token timeout issue
    // See: ENTRA_REFRESH_TOKEN_WORKAROUND.md for full documentation
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.mybartenderai.tokenRefreshKeepalive",
      frequency: NSNumber(value: 4 * 60 * 60) // 4 hours in seconds
    )

    // Check if app was launched from a local notification
    if let notification = launchOptions?[.localNotification] as? UILocalNotification {
      // Legacy iOS local notification (iOS < 10)
      if let userInfo = notification.userInfo, let payload = userInfo["payload"] as? String {
        print("[AppDelegate] Launched from legacy local notification with payload: \(payload)")
        UserDefaults.standard.set(payload, forKey: pendingNotificationKey)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle notification tap when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show the notification even when app is in foreground
    completionHandler([.banner, .badge, .sound])
  }

  // Handle notification tap - this is called when user taps a notification
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    print("[AppDelegate] Notification tapped!")
    print("[AppDelegate] UserInfo: \(userInfo)")

    // Extract payload from userInfo (flutter_local_notifications stores it there)
    if let payload = userInfo["payload"] as? String {
      print("[AppDelegate] Found payload: \(payload)")
      // Store in UserDefaults for Flutter to read
      UserDefaults.standard.set(payload, forKey: pendingNotificationKey)
      print("[AppDelegate] Saved payload to UserDefaults")
    }

    // Call super to let flutter_local_notifications handle it too
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
