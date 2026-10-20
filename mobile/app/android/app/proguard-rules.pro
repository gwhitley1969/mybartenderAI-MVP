# Keep rules here should be narrow. Don't add wholesale "-keep class <package>.** { *; }"
# rules for libraries that ship their own consumer rules (AndroidX, Flutter, RevenueCat,
# Play Billing): they stop R8 from shrinking, obfuscating and optimizing that code, and
# Play Console grades all three ("DEX code optimization"; below 25% can limit publishing).

# SharedPreferences - explicit keep rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }
-keep class android.content.SharedPreferences$OnSharedPreferenceChangeListener { *; }
-keep class ** implements android.content.SharedPreferences { *; }
-keep class ** implements android.content.SharedPreferences$Editor { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# AndroidX / Android framework: the libraries ship their own consumer rules
-dontwarn androidx.**
-dontwarn android.**

# Permission Handler plugin - keep all classes to prevent R8 stripping
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# RevenueCat / Purchases Flutter: the SDK's own consumer rules keep com.revenuecat.**
-dontwarn com.revenuecat.purchases.**

# RevenueCat's Amazon Appstore module (purchases-store-amazon). build.gradle.kts ignores
# its consumer rules because they include -dontoptimize; these are the rest of them.
-keep class com.amazon.** { *; }
-dontwarn com.amazon.**

# Google Play Billing
# Legacy AIDL package (pre-Billing-Library) — retained for safety
-keep class com.android.vending.billing.** { *; }
# Play Billing Library 8.x ships its own consumer rules
-dontwarn com.android.billingclient.**

# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Keep annotations
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers

# Google Play Core (deferred components - not used but referenced by Flutter)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# General Android keep rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
