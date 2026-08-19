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

# OneSignal — keep the FULL SDK. OneSignal's background/killed-state delivery
# depends on FCM classes (FirebaseMessagingService subclasses, broadcast
# receivers, the notification extender service) that are looked up via the
# merged manifest / reflection. If R8 renames or strips any of these, push
# notifications stop arriving the moment the app is swiped away from recents
# (the exact "works in background, fails when killed" symptom).
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# FCM — keep the messaging entry points used for killed-state delivery.
# Firebase ships consumer rules, but with minifyEnabled + aggressive shrinking
# an explicit keep here guarantees the MessagingService survives.
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

-dontwarn com.huawei.hms.**
-dontwarn com.huawei.agconnect.**
-dontwarn com.amazon.**
