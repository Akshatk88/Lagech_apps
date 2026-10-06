# Flutter Wrapper Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase Core & Messaging
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-dontwarn io.flutter.plugins.firebase.messaging.**
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Gson & JSON
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# AndroidX Core & Notifications
-keep class androidx.core.app.NotificationCompat** { *; }
-dontwarn androidx.**

# Play Core (Deferred components / SplitCompat)
-dontwarn com.google.android.play.core.**

