import Flutter
import UIKit
import UserNotifications // ✅ Para notificaciones
import Firebase // ✅ Para Firebase (si usas FCM)

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    // ✅ MÉTODO PRINCIPAL DE LANZAMIENTO
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // ✅ CONFIGURAR FIREBASE (si usas FCM)
        // FirebaseApp.configure()
        
        // ✅ CONFIGURAR NOTIFICACIONES
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in }
            )
        } else {
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        
        // ✅ GENERATED PLUGIN REGISTRANT
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // ✅ DELEGADO PARA EL IMPLICIT ENGINE
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
    
    // ✅ MANEJO DE NOTIFICACIONES EN BACKGROUND
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Aquí puedes manejar notificaciones en background
        completionHandler(.newData)
    }
    
    // ✅ REGISTRO EXITOSO DE NOTIFICACIONES
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Enviar token a Firebase o al servidor
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ DEVICE TOKEN: \(token)")
    }
    
    // ✅ ERROR AL REGISTRAR NOTIFICACIONES
    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ ERROR REGISTERING NOTIFICATIONS: \(error.localizedDescription)")
    }
    
    // ✅ MANEJO DE OPEN URL (para deep links)
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Aquí puedes manejar deep links
        return true
    }
}