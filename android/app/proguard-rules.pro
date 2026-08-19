# SpeakEasy R8 rules — keep only what reflection / JNI actually need.
# Broad `-keep class com.google.** { *; }` rules were blocking shrink/obfuscate
# (Play Console reported ~18% rates). Plugin AARs already ship consumer rules.

-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*, Exceptions, SourceFile, LineNumberTable

# Flutter engine / plugins (consumer rules cover most of this; keep JNI + embedding)
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class * implements io.flutter.embedding.engine.FlutterEngine { *; }

-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# App models that Hive / Firestore may reflect on (if any Java types exist)
-keep class com.speakeasy.english.learn.models.** { *; }

# flutter_local_notifications receivers declared in the manifest
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Play Core types referenced by Flutter's deferred-component manager
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# OneSignal: keep notification entry points; let R8 shrink the rest
-keep class com.onesignal.notifications.** { *; }
-keep class com.onesignal.OneSignal { *; }
-dontwarn com.huawei.hms.**
-dontwarn com.huawei.agconnect.**
-dontwarn com.amazon.**
