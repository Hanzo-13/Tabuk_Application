# Debug Development Guide

## Overview

This document explains how to develop and debug your Flutter application while preserving all security configurations for future release builds. Your recent security measures (ProGuard/R8, release signing, Network Security Configuration) are fully preserved but **inactive** during debug builds.

---

## 1. Build Configuration Analysis

### Debug Build Type Configuration

**Location:** `android/app/build.gradle.kts` → `buildTypes { debug { ... } }`

✅ **Confirmed:** The debug build type is correctly configured:

- **`isMinifyEnabled = false`** - Code minification/Obfuscation is **DISABLED**
  - This means your code runs exactly as written, making debugging straightforward
  - ProGuard/R8 rules in `proguard-rules.pro` are **NOT applied** during debug builds
  - You can set breakpoints, inspect variables, and read stack traces easily

- **Default Debug Signing** - Uses Android's automatically generated debug keystore
  - Debug keystore SHA-1 fingerprint matches your Google Maps API key configuration
  - **Release signing key (`upload-keystore.jks`) is NOT used** during debug builds
  - This is why your debug SHA-1 works with the Google Maps API

- **Debug API Key Fallback** - Includes a fallback key that matches your debug SHA-1
  - First tries `--dart-define=ANDROID_GOOGLE_MAPS_API_KEY=...`
  - Then tries environment variable `ANDROID_GOOGLE_MAPS_API_KEY` or `GOOGLE_MAPS_API_KEY`
  - Final fallback: Hardcoded debug API key for convenience

### Release Build Type Configuration

**Location:** `android/app/build.gradle.kts` → `buildTypes { release { ... } }`

✅ **Confirmed:** All release security features are preserved:

- **`isMinifyEnabled = true`** - Code minification is **ENABLED** (inactive during debug)
- **`proguardFiles(...)`** - ProGuard/R8 rules **WILL BE APPLIED** in release builds
- **Release Signing Configuration** - Ready to be activated (currently commented)
- **`isShrinkResources = true`** - Resource shrinking enabled for smaller APKs

---

## 2. How to Run Your Secure Debug App

### Option A: Running on a Connected Device/Emulator (Recommended for Development)

#### Basic Command (Using Default Debug API Key)
```bash
flutter run
```

This uses the hardcoded debug API key fallback in `build.gradle.kts` (line 79).

#### Using Custom Debug API Key via --dart-define
```bash
flutter run --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=your_debug_api_key_here
```

**Example:**
```bash
flutter run --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=AIzaSyDEeIzEOXmrCFNYt7f2QHM43lcq8fZtTsE
```

#### Running on Specific Device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

#### Hot Reload & Hot Restart
- Press `r` in the terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

---

### Option B: Building a Standalone Debug APK

#### Build Debug APK (No Custom API Key)
```bash
flutter build apk --debug
```

The APK will be located at: `build/app/outputs/flutter-apk/app-debug.apk`

#### Build Debug APK with Custom API Key
```bash
flutter build apk --debug --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=your_debug_api_key_here
```

**Example:**
```bash
flutter build apk --debug --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=AIzaSyDEeIzEOXmrCFNYt7f2QHM43lcq8fZtTsE
```

#### Build Debug APK Bundle (for Google Play testing)
```bash
flutter build appbundle --debug --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=your_debug_api_key_here
```

---

### Option C: Using Environment Variables

You can set environment variables instead of using `--dart-define`:

#### Linux/macOS
```bash
export ANDROID_GOOGLE_MAPS_API_KEY=your_debug_api_key_here
flutter run
```

#### Windows (PowerShell)
```powershell
$env:ANDROID_GOOGLE_MAPS_API_KEY="your_debug_api_key_here"
flutter run
```

#### Windows (Command Prompt)
```cmd
set ANDROID_GOOGLE_MAPS_API_KEY=your_debug_api_key_here
flutter run
```

---

## 3. Why Security Features Don't Affect Debug Builds

### ProGuard/R8 Rules (`proguard-rules.pro`)

**Why they're inactive in debug:**
- ProGuard/R8 only runs when `isMinifyEnabled = true`
- Debug builds have `isMinifyEnabled = false`
- The `proguardFiles()` directive is only processed during minification
- **Result:** Your `proguard-rules.pro` file is completely ignored during debug builds

**What this means:**
- All class names, method names, and package structures remain unchanged
- You can read full stack traces without obfuscation
- Reflection and dynamic code will work exactly as expected
- Debugging tools (Android Studio, VS Code) work perfectly

---

### Release Signing Key (`upload-keystore.jks`)

**Why it's not used in debug:**
- Debug builds use Android's default debug keystore (auto-generated)
- Location: `~/.android/debug.keystore` (or `%USERPROFILE%\.android\debug.keystore` on Windows)
- The debug keystore has a predictable SHA-1 fingerprint
- Google Maps API key is configured for this debug SHA-1 fingerprint

**What this means:**
- Your `upload-keystore.jks` file is completely unused during debug builds
- The release signing configuration in `key.properties` is inactive
- Google Maps API works because the API key matches the debug SHA-1
- When you're ready for release, uncomment the signing config and configure `key.properties`

---

### Network Security Configuration

**How it works in debug vs release:**
- `network_security_config.xml` applies to **both** debug and release builds
- However, the debug-only exceptions (localhost, 10.0.2.2) are **safe** because:
  - `localhost` is only accessible from the device itself
  - `10.0.2.2` only works in Android emulator (maps to host machine)
  - These can't be exploited in production apps on real devices
- The base configuration still enforces HTTPS for all other domains

**What this means:**
- You can connect to local development servers (`http://localhost:3000`)
- Emulator can access host machine via `http://10.0.2.2:3000`
- Production API endpoints still require HTTPS (enforced by base-config)
- No security risk - the debug exceptions are device/emulator only

---

## 4. Debug vs Release Comparison

| Feature | Debug Build | Release Build |
|---------|------------|---------------|
| **Code Minification** | ❌ Disabled | ✅ Enabled |
| **ProGuard/R8 Rules** | ❌ Not Applied | ✅ Applied |
| **Signing Key** | Debug keystore (auto) | `upload-keystore.jks` (custom) |
| **API Key Source** | Fallback available | Must be provided explicitly |
| **APK Size** | Larger (~50-100MB) | Smaller (~15-30MB, optimized) |
| **Stack Traces** | Full, readable | Obfuscated (unless ProGuard rules preserve) |
| **Resource Shrinking** | ❌ Disabled | ✅ Enabled |
| **Debugging** | ✅ Full support | ⚠️ Limited (code is obfuscated) |

---

## 5. Verifying Debug Configuration

### Check Current Build Type
Look for these indicators:

1. **In LogCat/Console:**
   - Debug builds show: `BuildConfig.DEBUG = true`
   - Release builds show: `BuildConfig.DEBUG = false`

2. **App Info on Device:**
   - Debug: App name may show "-debug" suffix (if configured)
   - Release: Clean app name

3. **APK Size:**
   - Debug APK: Usually 50-100MB
   - Release APK: Usually 15-30MB (after minification and shrinking)

### Verify Google Maps is Working
1. Launch your app
2. Navigate to a screen with Google Maps
3. If the map loads correctly, your debug configuration is working
4. If you see "Google Maps API error," check:
   - API key is correctly passed via `--dart-define`
   - API key matches your debug SHA-1 fingerprint
   - Internet connection is active

---

## 6. Troubleshooting Debug Issues

### Google Maps Not Loading

**Symptom:** Map shows gray screen or "API error"

**Solutions:**
1. **Verify API key is being passed:**
   ```bash
   flutter run --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=your_key --verbose
   ```
   Look for `GOOGLE_MAPS_API_KEY` in the build output

2. **Check SHA-1 fingerprint matches:**
   ```bash
   # Get debug keystore SHA-1
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   Ensure this SHA-1 is added to your Google Maps API key restrictions

3. **Verify API key restrictions:**
   - In Google Cloud Console, check your API key
   - Ensure "Android apps" is enabled
   - Package name: `com.example.capstone_app.debug` (with `.debug` suffix if configured)

### Build Errors

**Error:** `GOOGLE_MAPS_API_KEY not found`
- **Solution:** Use `--dart-define=ANDROID_GOOGLE_MAPS_API_KEY=...` or ensure fallback key is in `build.gradle.kts`

**Error:** `Signing config not found`
- **Solution:** This shouldn't happen in debug. If it does, ensure `signingConfigs.getByName("debug")` exists (it's auto-generated)

---

## 7. Transitioning to Release Build

When you're ready to build a release APK:

1. **Configure Release Signing:**
   - Uncomment the `signingConfigs` block in `build.gradle.kts`
   - Update `android/key.properties` with your release keystore details
   - Change `signingConfig = signingConfigs.getByName("release")` in release buildType

2. **Get Release SHA-1:**
   ```bash
   keytool -list -v -keystore /path/to/upload-keystore.jks -alias upload
   ```

3. **Add Release SHA-1 to Google Maps API Key:**
   - Go to Google Cloud Console
   - Add the release SHA-1 fingerprint to your API key restrictions

4. **Build Release APK:**
   ```bash
   flutter build apk --release --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=your_release_key
   ```

---

## 8. Summary

✅ **Your debug environment is fully functional:**
- No code minification → Easy debugging
- Debug signing → Google Maps API works with debug SHA-1
- Debug API key fallback → Convenient development
- Network exceptions → Local development server access

✅ **Your release security is fully preserved:**
- ProGuard/R8 rules ready → Will apply in release builds
- Release signing config ready → Just uncomment and configure
- Network security enforced → HTTPS required for production APIs
- Resource shrinking enabled → Smaller release APKs

**You can now develop and debug freely while knowing all security infrastructure is ready for production!**

---

## Additional Resources

- [Flutter Build Modes](https://docs.flutter.dev/testing/build-modes)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [ProGuard Configuration](https://developer.android.com/studio/build/shrink-code)
- [Google Maps API Setup](https://developers.google.com/maps/documentation/android-sdk/get-api-key)

