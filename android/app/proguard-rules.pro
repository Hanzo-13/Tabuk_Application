# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# === THE FIX IS HERE: Keep essential Flutter engine classes ===
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-keepnames class com.google.android.gms.measurement.AppMeasurement.ConditionalUserProperty
-keep public class com.google.firebase.analytics.FirebaseAnalytics
-keep public class com.google.firebase.crashlytics.FirebaseCrashlytics

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