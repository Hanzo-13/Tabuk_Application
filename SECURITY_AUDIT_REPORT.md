# Security Audit Report - Tabuk Application
## Multi-Platform Security Analysis (Web, iOS, Android)

**Date:** Generated Report  
**Application:** Capstone App (Tabuk)  
**Platforms:** Web, iOS, Android  
**Audit Scope:** Authentication, Data Storage, Network Security, API Security, Platform Configurations

---

## Executive Summary

This security audit identified **multiple critical and high-priority security vulnerabilities** across all three platforms. The application requires immediate implementation of additional security layers to protect user data, API keys, and prevent unauthorized access.

### Overall Security Score: 4/10

**Critical Issues Found:** 5  
**High Priority Issues:** 8  
**Medium Priority Issues:** 4

---

## 🔴 CRITICAL SECURITY ISSUES

### 1. **Hardcoded API Keys and Credentials (ALL PLATFORMS)**

**Severity:** CRITICAL  
**Impact:** Unauthorized access to Google Maps API, Firebase, and third-party services

#### Issues Found:
- **Google Maps API Keys** exposed in multiple locations:
  - `web/index.html` (line 20): `AIzaSyCZ-Sc9QsAox-vIPU_q8l5XqGs1B4Ed01U`
  - `android/app/src/main/AndroidManifest.xml` (line 16): `AIzaSyDEeIzEOXmrCFNYt7f2QHM43lcq8fZtTsE`
  - `ios/Runner/AppDelegate.swift` (line 14): `AIzaSyATZftO3SXnK0-sWqq3-5Ew5eHcUvGAhL8`
  - `lib/api/api.dart` (line 12): `AIzaSyCHDrbJrZHSeMFG40A-hQPB37nrmA6rUKE`
  - `directions-proxy/index.js` (line 8): `AIzaSyCHDrbJrZHSeMFG40A-hQPB37nrmA6rUKE`

- **Firebase Configuration** exposed in `web/index.html`:
  - API Key: `AIzaSyBqUNC1h2O3pseeDYdRjfYCkSfGBwbnVis`
  - Project ID, Storage Bucket, and other credentials

- **Third-party API Key** in `lib/screens/tourist/profile/edit_tourist_profile.dart`:
  - ImgBB API Key: `aae8c93b12878911b39dd9abc8c73376`

**Risk:** These keys can be extracted from the compiled application and used maliciously, leading to:
- Excessive API usage and billing fraud
- Unauthorized access to services
- Rate limiting and service disruption

---

### 2. **Passwords Stored in Firestore Database**

**Severity:** CRITICAL  
**Location:** `lib/services/auth_service.dart` (line 496)

```dart
'password': password ?? '',
```

**Issue:** Plaintext or potentially stored passwords in Firestore user documents, despite Firebase Auth handling authentication.

**Risk:** 
- Password exposure if Firestore is compromised
- Violation of security best practices
- Regulatory compliance issues (GDPR, CCPA)

---

### 3. **Insecure Session Storage (ALL PLATFORMS)**

**Severity:** CRITICAL  
**Location:** `lib/services/session_services.dart`

**Issue:** Using `SharedPreferences` instead of secure storage for sensitive session data:
- User IDs
- Email addresses  
- User roles
- Authentication state

**Risk:**
- **Android:** SharedPreferences stored in plaintext XML files
- **iOS:** Keychain should be used instead
- **Web:** LocalStorage is accessible to JavaScript and vulnerable to XSS

**Current Implementation:**
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString(_keyUserId, uid);
await prefs.setString(_keyUserEmail, email);
```

**Note:** The project includes `flutter_secure_storage` in dependencies but it's **not being used** for session data.

---

### 4. **iOS: App Transport Security Disabled**

**Severity:** CRITICAL  
**Location:** `ios/Runner/Info.plist` (lines 9-13)

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Issue:** Allows insecure HTTP connections, bypassing iOS security requirements.

**Risk:**
- Man-in-the-middle attacks
- Data interception
- Violation of App Store guidelines

---

### 5. **Android: Missing Network Security Configuration**

**Severity:** CRITICAL  
**Location:** `android/app/src/main/AndroidManifest.xml`

**Issue:** No network security configuration file, allowing cleartext traffic.

**Risk:**
- HTTP connections allowed (should require HTTPS)
- No certificate pinning
- Vulnerable to network attacks

---

## 🟠 HIGH PRIORITY SECURITY ISSUES

### 6. **No Code Obfuscation (Android)**

**Severity:** HIGH  
**Location:** `android/app/build.gradle.kts`

**Issue:** 
- ProGuard is enabled but no custom rules file exists
- Code is easily reverse-engineered
- Business logic and API keys are exposed

**Current State:**
```kotlin
isMinifyEnabled = true
proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
// But proguard-rules.pro doesn't exist!
```

---

### 7. **Debug Signing Configuration in Release Build**

**Severity:** HIGH  
**Location:** `android/app/build.gradle.kts` (line 55)

```kotlin
signingConfig = signingConfigs.getByName("debug")
```

**Issue:** Release builds are signed with debug keys instead of production keys.

**Risk:**
- Apps can be easily tampered with
- Violates Google Play Store requirements

---

### 8. **Web: Firebase Configuration Exposed in Client-Side Code**

**Severity:** HIGH  
**Location:** `web/index.html` (lines 38-47)

**Issue:** Full Firebase configuration including API keys visible in HTML source.

**Risk:** 
- Firebase API key abuse
- Unauthorized database access if rules are weak
- Increased Firebase usage costs

---

### 9. **No Certificate Pinning**

**Severity:** HIGH  
**Platforms:** All

**Issue:** No SSL/TLS certificate pinning implemented for API calls.

**Risk:**
- Man-in-the-middle attacks
- Compromised certificate authorities could intercept traffic

---

### 10. **Weak Firestore Security Rules**

**Severity:** HIGH  
**Location:** `firestore_rules.txt`

**Issues:**
- Line 20: All authenticated users can read any user document
  ```javascript
  allow read: if isSignedIn();
  ```
- No rate limiting
- No field-level encryption
- Sensitive data (if any) not protected

**Risk:** Unauthorized data access, data scraping, privacy violations.

---

### 11. **No Input Validation for Sensitive Operations**

**Severity:** HIGH  
**Location:** Multiple services

**Issue:** Limited input validation and sanitization for:
- User registration
- API calls
- File uploads
- Location data

---

### 12. **Session Management Vulnerabilities**

**Severity:** HIGH  
**Location:** `lib/services/auth_service.dart`

**Issues:**
- No session timeout
- No concurrent session limits
- Session stored in insecure storage
- No automatic logout on token expiration

---

### 13. **Missing Security Headers (Web)**

**Severity:** HIGH  
**Location:** `web/index.html`

**Issue:** No Content Security Policy (CSP), X-Frame-Options, or other security headers.

**Risk:**
- XSS attacks
- Clickjacking
- MIME type sniffing attacks

---

## 🟡 MEDIUM PRIORITY ISSUES

### 14. **No Rate Limiting**

**Severity:** MEDIUM  
**Platforms:** All

**Issue:** API calls and authentication attempts have no rate limiting.

**Risk:** Brute force attacks, API abuse, denial of service.

---

### 15. **Error Messages May Leak Information**

**Severity:** MEDIUM  
**Location:** Authentication error handling

**Issue:** Detailed error messages may reveal system information or help attackers.

---

### 16. **No Biometric Authentication**

**Severity:** MEDIUM  
**Platforms:** Mobile

**Issue:** No fingerprint/Face ID authentication option.

---

### 17. **Dependencies Not Audited for Vulnerabilities**

**Severity:** MEDIUM  
**Location:** `pubspec.yaml`

**Issue:** No evidence of dependency vulnerability scanning.

---

## Platform-Specific Analysis

### 🌐 Web Platform Security Score: 3/10

**Critical Issues:**
- API keys exposed in HTML
- Firebase config exposed
- No security headers
- Using LocalStorage for sensitive data
- No CSP implementation

**Recommendations:**
- Move API keys to backend proxy
- Implement security headers
- Use secure cookies or HttpOnly cookies
- Add Content Security Policy

---

### 📱 iOS Platform Security Score: 4/10

**Critical Issues:**
- App Transport Security disabled
- API keys in AppDelegate.swift
- Using SharedPreferences (should use Keychain)
- No certificate pinning

**Recommendations:**
- Enable ATS with exception domains only
- Use environment variables or secure config
- Implement flutter_secure_storage
- Add certificate pinning

---

### 🤖 Android Platform Security Score: 3/10

**Critical Issues:**
- API keys in AndroidManifest.xml
- Debug signing in release builds
- No network security config
- Missing ProGuard rules
- Using SharedPreferences for sensitive data

**Recommendations:**
- Implement network security configuration
- Use build variants for API keys
- Create production signing config
- Write comprehensive ProGuard rules
- Use flutter_secure_storage

---

## Security Recommendations Summary

### Immediate Actions Required (Week 1)

1. ✅ Remove all hardcoded API keys
2. ✅ Remove password storage from Firestore
3. ✅ Implement flutter_secure_storage for session data
4. ✅ Enable App Transport Security on iOS (with proper exceptions)
5. ✅ Create Android Network Security Configuration

### High Priority (Week 2-3)

6. ✅ Move API keys to environment variables/build configs
7. ✅ Implement certificate pinning
8. ✅ Add ProGuard rules for Android
9. ✅ Configure production signing for Android
10. ✅ Tighten Firestore security rules
11. ✅ Add security headers for web

### Medium Priority (Month 1)

12. ✅ Implement rate limiting
13. ✅ Add input validation and sanitization
14. ✅ Add session timeout mechanisms
15. ✅ Implement dependency vulnerability scanning
16. ✅ Add Content Security Policy for web

---

## Compliance & Regulatory Considerations

- **GDPR:** Password storage in Firestore may violate GDPR requirements
- **CCPA:** Similar privacy concerns with data storage
- **OWASP Top 10:** Multiple vulnerabilities align with OWASP Top 10 risks
- **App Store Guidelines:** iOS ATS violation may cause rejection

---

## Conclusion

The application requires **significant security improvements** before production deployment. The most critical issues are the exposure of API keys, insecure session storage, and platform-specific security misconfigurations. 

**Estimated Effort:** 3-4 weeks for critical fixes, 2-3 months for comprehensive security hardening.

**Next Steps:** Implementation of recommended security layers should begin immediately, starting with the critical issues identified in this report.


