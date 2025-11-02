import Flutter
import UIKit
import FirebaseCore
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Try to load API key from Info.plist first
    var apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String
    
    // Fallback to hardcoded key for development (TODO: Remove in production)
    if apiKey == nil || apiKey!.isEmpty {
      apiKey = "AIzaSyATZftO3SXnK0-sWqq3-5Ew5eHcUvGAhL8" // Your iOS API key
    }
    
    guard let finalApiKey = apiKey, !finalApiKey.isEmpty else {
      fatalError("Google Maps API Key not found")
    }
    
    GMSServices.provideAPIKey(finalApiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}