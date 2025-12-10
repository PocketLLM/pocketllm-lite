# ============================================================================
# ProGuard Rules for Pocket LLM Lite
# ============================================================================
# These rules configure R8/ProGuard for code shrinking, optimization, and
# obfuscation while preserving functionality of all app features.
# ============================================================================

# ============================================================================
# GENERAL FLUTTER RULES
# ============================================================================
# Keep Flutter plugin classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep plugin common classes
-keep class io.flutter.plugin.common.** { *; }

# ============================================================================
# GOOGLE MOBILE ADS (AdMob)
# ============================================================================
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.**

# Keep AdMob internal classes
-keep class com.google.android.gms.internal.ads.** { *; }
-keepclassmembers class com.google.android.gms.ads.** { *; }

# ============================================================================
# GOOGLE PLAY CORE (Deferred Components, Split Install)
# ============================================================================
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# ============================================================================
# GOOGLE PLAY SERVICES
# ============================================================================
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ============================================================================
# HIVE DATABASE
# ============================================================================
-keep class io.hivedb.** { *; }
-keep class com.techiedelight.hive.** { *; }
-keep class hive.** { *; }
-keep class * extends hive.TypeAdapter { *; }
-dontwarn hive.**

# Keep generated Hive adapters (TypeAdapters)
-keep class **$HiveAdapter { *; }
-keep class **Adapter { *; }

# ============================================================================
# IMAGE PICKER
# ============================================================================
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.crazecoder.openfile.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ============================================================================
# PERMISSION HANDLER
# ============================================================================
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ============================================================================
# PATH PROVIDER
# ============================================================================
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# ============================================================================
# SHARED PREFERENCES
# ============================================================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# ============================================================================
# CONNECTIVITY PLUS
# ============================================================================
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ============================================================================
# PACKAGE INFO PLUS
# ============================================================================
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-dontwarn dev.fluttercommunity.plus.packageinfo.**

# ============================================================================
# URL LAUNCHER
# ============================================================================
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# ============================================================================
# HTTP/NETWORKING (OkHttp, Okio)
# ============================================================================
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# Keep HTTP client internals
-keepclassmembers class * implements okhttp3.Callback { *; }

# ============================================================================
# SERIALIZATION (JSON PARSING)
# ============================================================================
# Keep classes that implement Serializable
-keep class * implements java.io.Serializable { *; }
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Gson classes if used
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ============================================================================
# KOTLIN
# ============================================================================
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Keep Kotlin Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# ============================================================================
# ANDROID CORE
# ============================================================================
# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom Application class
-keep public class * extends android.app.Application

# Keep activities
-keep public class * extends android.app.Activity
-keep public class * extends androidx.fragment.app.Fragment

# Keep services and receivers
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep View constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ============================================================================
# ANNOTATIONS
# ============================================================================
-dontwarn javax.annotation.**
-dontwarn android.annotation.**
-keep class androidx.annotation.** { *; }
-keep interface androidx.annotation.** { *; }

# ============================================================================
# DEBUGGING - Remove for production to reduce size
# ============================================================================
# Preserve line numbers for stack traces
-keepattributes SourceFile,LineNumberTable

# Hide original source file name
-renamesourcefileattribute SourceFile

# ============================================================================
# OPTIMIZATION SETTINGS
# ============================================================================
# Don't optimize arithmetic operations (can cause issues)
-optimizations !code/simplification/arithmetic

# Keep attributes needed for reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

# ============================================================================
# ADDITIONAL SAFETY RULES
# ============================================================================
# Keep classes called from native code
-keep class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Preserve all public methods in public classes
-keep public class * {
    public *;
}
