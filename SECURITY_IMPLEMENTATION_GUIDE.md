# Security Implementation Guide
## Step-by-Step Fixes for Critical Security Issues

This guide provides concrete implementation steps to address the security vulnerabilities identified in the audit report.

---

## 🔴 CRITICAL FIXES

### Fix 1: Remove Hardcoded API Keys

#### Step 1.1: Create Environment Configuration System

Create `lib/config/env_config.dart`:

```dart
import 'package:flutter/foundation.dart';

class EnvConfig {
  // Load from environment variables or secure storage
  static String get googleMapsApiKey {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: '', // Fail safely - require environment variable
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment(
        'ANDROID_GOOGLE_MAPS_API_KEY',
        defaultValue: '',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const String.fromEnvironment(
        'IOS_GOOGLE_MAPS_API_KEY',
        defaultValue: '',
      );
    }
    return '';
  }
  
  static String get firebaseApiKey {
    return const String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: '',
    );
  }
  
  static String get firebaseProjectId {
    return const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: '',
    );
  }
  
  static String get imgbbApiKey {
    return const String.fromEnvironment(
      'IMGBB_API_KEY',
      defaultValue: '',
    );
  }
  
  static void validate() {
    assert(
      googleMapsApiKey.isNotEmpty,
      'Google Maps API Key must be provided via environment variable',
    );
  }
}
```

#### Step 1.2: Update API Service

Update `lib/api/api.dart`:

```dart
import 'package:capstone_app/config/env_config.dart';

class ApiEnvironment {
  static String get googleDirectionsApiKey => EnvConfig.googleMapsApiKey;
  
  // Rest of the code...
}
```

#### Step 1.3: Android - Use Build Configuration

Update `android/app/build.gradle.kts`:

```kotlin
android {
    // ... existing code ...
    
    buildTypes {
        release {
            // Load from local.properties or environment
            val googleMapsKey = project.findProperty("GOOGLE_MAPS_API_KEY") 
                ?: System.getenv("GOOGLE_MAPS_API_KEY") 
                ?: ""
            
            buildConfigField("String", "GOOGLE_MAPS_API_KEY", "\"$googleMapsKey\"")
            
            signingConfig = signingConfigs.getByName("release") // Create this!
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
        debug {
            val googleMapsKey = project.findProperty("GOOGLE_MAPS_API_KEY") 
                ?: System.getenv("GOOGLE_MAPS_API_KEY") 
                ?: ""
            buildConfigField("String", "GOOGLE_MAPS_API_KEY", "\"$googleMapsKey\"")
        }
    }
}
```

Create `android/local.properties` (add to .gitignore):
```
GOOGLE_MAPS_API_KEY=your_key_here
```

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}"/>
```

#### Step 1.4: iOS - Use Xcode Build Settings

Update `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Load from Info.plist or environment
    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
          let dict = NSDictionary(contentsOfFile: path),
          let apiKey = dict["GOOGLE_MAPS_API_KEY"] as? String else {
        fatalError("Google Maps API Key not found")
    }
    
    GMSServices.provideAPIKey(apiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Add to `ios/Runner/Info.plist`:
```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

#### Step 1.5: Web - Use Environment Variables

Update `web/index.html`:

```html
<script>
  // Load from environment variable or fetch from backend
  const GOOGLE_MAPS_API_KEY = '${GOOGLE_MAPS_API_KEY}' || 
    (await fetch('/api/config').then(r => r.json())).googleMapsKey;
  
  // Use in script tag:
  <script src="https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}"></script>
</script>
```

**Better Approach:** Create a backend endpoint to serve API keys securely.

---

### Fix 2: Implement Secure Storage for Sessions

#### Step 2.1: Update pubspec.yaml

Ensure `flutter_secure_storage` is included (it already is, but verify version):

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

#### Step 2.2: Create Secure Session Service

Create `lib/services/secure_session_service.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureSessionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Use KeyStore for additional security
      sharedPreferencesName: 'secure_session',
      preferencesKeyPrefix: 'session_',
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
      // Use Keychain
    ),
    lOptions: LinuxOptions(
      useSessionKeyring: true,
    ),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
  );

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';

  /// Store session data securely
  static Future<void> storeSession(
    String uid,
    String email,
    String role,
  ) async {
    try {
      await Future.wait([
        _storage.write(key: _keyIsLoggedIn, value: 'true'),
        _storage.write(key: _keyUserId, value: uid),
        _storage.write(key: _keyUserEmail, value: email),
        _storage.write(key: _keyUserRole, value: role),
      ]);
      debugPrint('Session stored securely');
    } catch (e) {
      debugPrint('Error storing session: $e');
      rethrow;
    }
  }

  /// Clear all session data
  static Future<void> clearSession() async {
    try {
      await _storage.deleteAll();
      debugPrint('Session cleared');
    } catch (e) {
      debugPrint('Error clearing session: $e');
      rethrow;
    }
  }

  /// Check if session exists
  static Future<bool> hasValidSession() async {
    try {
      final isLoggedIn = await _storage.read(key: _keyIsLoggedIn);
      return isLoggedIn == 'true';
    } catch (e) {
      debugPrint('Error checking session: $e');
      return false;
    }
  }

  /// Get session data
  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final isLoggedIn = await _storage.read(key: _keyIsLoggedIn);
      if (isLoggedIn != 'true') return null;

      final uid = await _storage.read(key: _keyUserId);
      final email = await _storage.read(key: _keyUserEmail);
      final role = await _storage.read(key: _keyUserRole);

      if (uid != null && email != null && role != null) {
        return {
          'uid': uid,
          'email': email,
          'role': role,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving session: $e');
      return null;
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Get user email
  static Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }
}
```

#### Step 2.3: Update Auth Service

Update `lib/services/auth_service.dart` to use `SecureSessionService` instead of `SessionService`:

```dart
// Replace SessionService with SecureSessionService
import 'package:capstone_app/services/secure_session_service.dart';

// In signInWithEmailPasswordWithPersistence:
await SecureSessionService.storeSession(
  userCredential.user!.uid,
  userCredential.user!.email ?? '',
  role,
);

// In signOut:
await SecureSessionService.clearSession();
```

---

### Fix 3: Remove Password Storage from Firestore

#### Update storeUserData method

In `lib/services/auth_service.dart` (line 482-505):

```dart
/// Store user data in Firestore.
static Future<void> storeUserData(
  String uid,
  String email,
  String role, {
  String? username,
  // REMOVE password parameter
  bool appEmailVerified = false,
}) async {
  try {
    await FirebaseFirestore.instance.collection('Users').doc(uid).set({
      'user_id': uid,
      'role': role,
      'username': username ?? '',
      'email': email,
      // REMOVED: 'password': password ?? '',
      'created_at': FieldValue.serverTimestamp(),
      'app_email_verified': appEmailVerified,
    }, SetOptions(merge: true));
    debugPrint('User data stored/updated for $uid');
  } catch (e) {
    debugPrint('Error storing user data: $e');
    rethrow;
  }
}
```

#### Remove password from updateUserData

```dart
static Future<void> updateUserData(
  String uid, {
  String? email,
  String? role,
  String? username,
  // REMOVE: String? password,
  String? municipality,
  String? status,
  String? profilePhoto,
}) async {
  try {
    await FirebaseFirestore.instance.collection('Users').doc(uid).set({
      'user_id': uid,
      'role': role,
      'username': username ?? '',
      'email': email,
      // REMOVED: 'password': password ?? '',
      'municipality': municipality ?? '',
      'status': status ?? '',
      'profile_photo': profilePhoto ?? '',
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('Error updating user data: $e');
  }
}
```

#### Clean existing password data

Create a migration script to remove passwords from existing Firestore documents.

---

### Fix 4: Enable iOS App Transport Security

#### Update Info.plist

Update `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <!-- Remove NSAllowsArbitraryLoads -->
    <!-- Allow specific exceptions if needed -->
    <key>NSExceptionDomains</key>
    <dict>
        <!-- Example for a specific domain that needs HTTP -->
        <key>example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
    <!-- Require TLS 1.2 minimum -->
    <key>NSTLSExceptionMinimumTLSVersion</key>
    <string>TLSv1.2</string>
</dict>
```

**Note:** Remove `NSAllowsArbitraryLoads` completely. Only add exception domains if absolutely necessary.

---

### Fix 5: Android Network Security Configuration

#### Step 5.1: Create Network Security Config

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Base configuration for all connections -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <!-- Trust system certificates -->
            <certificates src="system" />
            <!-- Optional: Add custom certificates for certificate pinning -->
            <!-- <certificates src="@raw/custom_certificate" /> -->
        </trust-anchors>
    </base-config>
    
    <!-- Domain-specific configuration if needed -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">firebaseapp.com</domain>
        <domain includeSubdomains="true">googleapis.com</domain>
        <domain includeSubdomains="true">gstatic.com</domain>
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </domain-config>
    
    <!-- Debug-only: Allow cleartext for localhost (development only) -->
    <!-- Remove in production builds -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

#### Step 5.2: Reference in AndroidManifest

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:label="Tabuk"
    android:name="${applicationName}"
    android:icon="@mipmap/launcher_icon"
    android:hardwareAccelerated="true"
    android:largeHeap="true"
    android:networkSecurityConfig="@xml/network_security_config">
    <!-- ... rest of configuration ... -->
</application>
```

---

### Fix 6: Android Production Signing Configuration

#### Step 6.1: Create Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

#### Step 6.2: Create key.properties

Create `android/key.properties` (add to .gitignore):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

#### Step 6.3: Update build.gradle.kts

```kotlin
// Load key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing code ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release") // Use release signing
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}
```

---

### Fix 7: ProGuard Rules for Android

#### Create proguard-rules.pro

Create `android/app/proguard-rules.pro`:

```proguard
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }

# Obfuscate application code
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
```

---

### Fix 8: Web Security Headers

#### Create backend middleware or update index.html

For static hosting, create `web/.htaccess` (Apache) or configure server headers:

```apache
# Security Headers
Header set X-Content-Type-Options "nosniff"
Header set X-Frame-Options "DENY"
Header set X-XSS-Protection "1; mode=block"
Header set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://*.googleapis.com https://*.gstatic.com https://accounts.google.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com https://*.firebaseapp.com"
Header set Referrer-Policy "strict-origin-when-cross-origin"
Header set Permissions-Policy "geolocation=(), microphone=(), camera=()"
```

---

### Fix 9: Implement Certificate Pinning (Optional but Recommended)

#### For Flutter HTTP calls

Use `http_certificate_pinning` package:

```yaml
dependencies:
  http_certificate_pinning: ^2.0.0
```

```dart
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

final client = HttpCertificatePinning(
  allowedSHAFingerprints: [
    "SHA256_FINGERPRINT_HERE", // From server certificate
  ],
);
```

---

## 🔧 Additional Security Enhancements

### Rate Limiting

Implement rate limiting for authentication attempts using Firebase App Check or custom backend.

### Session Timeout

Add to `secure_session_service.dart`:

```dart
static Future<void> storeSessionWithExpiry(...) async {
  await storeSession(...);
  await _storage.write(
    key: 'session_expiry',
    value: DateTime.now().add(Duration(hours: 24)).toIso8601String(),
  );
}

static Future<bool> isSessionValid() async {
  final expiry = await _storage.read(key: 'session_expiry');
  if (expiry == null) return false;
  
  final expiryDate = DateTime.parse(expiry);
  return DateTime.now().isBefore(expiryDate);
}
```

### Input Validation

Create validation utilities and apply to all user inputs.

---

## 📋 Checklist

- [ ] Remove all hardcoded API keys
- [ ] Implement environment variable system
- [ ] Migrate to flutter_secure_storage
- [ ] Remove password storage from Firestore
- [ ] Enable iOS App Transport Security
- [ ] Create Android Network Security Config
- [ ] Configure production signing
- [ ] Add ProGuard rules
- [ ] Add web security headers
- [ ] Update Firestore rules
- [ ] Implement certificate pinning
- [ ] Add rate limiting
- [ ] Implement session timeout

---

## 🚀 Build Commands

After implementing fixes:

**Android:**
```bash
flutter build apk --release --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=AIzaSyDEeIzEOXmrCFNYt7f2QHM43lcq8fZtTsE
```

**iOS:**
```bash
flutter build ios --release --dart-define=IOS_GOOGLE_MAPS_API_KEY=AIzaSyATZftO3SXnK0-sWqq3-5Ew5eHcUvGAhL8
```

**Web:**
```bash
flutter build web --release --dart-define=GOOGLE_MAPS_API_KEY=your_key
```

---

## 📝 Notes

1. Always test thoroughly after implementing security changes
2. Keep backup of keys in secure password manager (not in code)
3. Rotate API keys if they've been exposed
4. Monitor API usage after deployment
5. Consider implementing API key rotation mechanism


