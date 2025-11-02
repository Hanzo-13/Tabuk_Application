# Quick Debug Start Guide

## ✅ Your Debug Environment is Ready!

All security configurations are preserved but **inactive** during debug builds. You can now develop freely.

---

## 🚀 Run Your App (Choose One)

### Option 1: Simple (Uses Fallback API Key)
```bash
flutter run
```

### Option 2: With Custom Debug API Key
```bash
flutter run --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=your_debug_key_here
```

### Option 3: Build Debug APK
```bash
flutter build apk --debug --dart-define=ANDROID_GOOGLE_MAPS_API_KEY=your_debug_key_here
```

---

## 🔍 What's Different in Debug vs Release?

| Feature | Debug | Release |
|---------|-------|---------|
| Code Minification | ❌ OFF | ✅ ON |
| ProGuard/R8 Rules | ❌ Not Applied | ✅ Applied |
| Signing Key | Debug (auto) | upload-keystore.jks |
| Google Maps API | ✅ Works (debug SHA-1) | Needs release SHA-1 |

---

## 📋 Build Configuration Summary

### ✅ Debug Build (`build.gradle.kts` lines 82-111)
- `isMinifyEnabled = false` → No code obfuscation
- ProGuard rules **NOT applied** → Easy debugging
- Uses debug signing → Matches your debug SHA-1 API key
- Has API key fallback → Convenient development

### ✅ Release Build (`build.gradle.kts` lines 113-146)
- `isMinifyEnabled = true` → Code optimization
- ProGuard rules **WILL BE APPLIED** → Preserved
- Release signing ready → Just uncomment when needed
- No API key fallback → Requires explicit key

---

## 🔐 Security Features Status

### ✅ Preserved (Inactive in Debug)
- ✅ ProGuard/R8 rules (`proguard-rules.pro`) - Ready for release
- ✅ Release signing config (commented) - Ready to activate
- ✅ Network Security Config - Enforces HTTPS (except localhost)

### ✅ Active (Debug-Safe)
- ✅ Debug signing (auto-generated)
- ✅ Debug API key fallback
- ✅ Localhost HTTP allowed (development only)

---

## 🛠️ Troubleshooting

**Google Maps not loading?**
1. Verify API key matches debug SHA-1 fingerprint
2. Check API key is passed: `flutter run --verbose`
3. Ensure package name matches in Google Cloud Console

**Need full details?**
See `DEBUG_DEVELOPMENT_GUIDE.md` for comprehensive documentation.

---

## 📚 Next Steps

1. **Start developing:** `flutter run`
2. **Test features:** Use hot reload (`r` in terminal)
3. **Build APK:** `flutter build apk --debug`
4. **When ready for release:** See `DEBUG_DEVELOPMENT_GUIDE.md` section 7

---

**Your security infrastructure is preserved and ready for production! 🎉**

